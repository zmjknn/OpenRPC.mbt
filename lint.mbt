///|
/// Semantic diagnostics for an already parsed OpenRPC document.
///
/// Parsing answers whether a document has the expected JSON shape. Linting is
/// a separate, non-mutating pass for rules that need the complete declaration
/// context, such as positional optionality and recursive schema boundaries.
pub fn Document::lint(self : Document) -> Array[Diagnostic] {
  let diagnostics : Array[Diagnostic] = []
  for method_index, method_value in self.methods {
    let method_path = "$.methods[" + method_index.to_string() + "]"
    lint_method(method_value, method_path, diagnostics)
  }
  diagnostics
}

///|
/// Lint method-level names, parameter ordering, and child schemas.
fn lint_method(
  method_value : Method,
  method_path : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  if method_value.name.length() == 0 {
    diagnostics.push(
      diagnostic(
        method_path + ".name",
        EmptyMethodName,
        "method name must not be empty",
      ),
    )
  }
  let mut optional_seen = false
  for index, parameter in method_value.params {
    let parameter_path = method_path + ".params[" + index.to_string() + "]"
    if parameter.name.length() == 0 {
      diagnostics.push(
        diagnostic(
          parameter_path + ".name",
          EmptyParameterName,
          "parameter name must not be empty",
        ),
      )
    }
    for previous_index in 0..<index {
      if method_value.params[previous_index].name == parameter.name {
        diagnostics.push(
          diagnostic(
            parameter_path + ".name",
            DuplicateParameter,
            "parameter names must be unique within a method",
          ),
        )
        break
      }
    }
    if parameter.required && optional_seen {
      diagnostics.push(
        diagnostic(
          parameter_path,
          OptionalBeforeRequired,
          "a required positional parameter follows an optional parameter",
        ),
      )
    }
    if !parameter.required {
      optional_seen = true
    }
    lint_schema(parameter.schema, parameter_path + ".schema", diagnostics)
  }
  match method_value.result {
    None => ()
    Some(result) => {
      let result_path = method_path + ".result"
      if result.name.length() == 0 {
        diagnostics.push(
          diagnostic(
            result_path + ".name",
            EmptyResultName,
            "result name must not be empty",
          ),
        )
      }
      lint_schema(result.schema, result_path + ".schema", diagnostics)
    }
  }
}

///|
/// Recursively lint a supported schema value and its structural boundaries.
fn lint_schema(
  schema : Json,
  path : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  match schema {
    True | False => ()
    Object(schema_object) =>
      lint_schema_object(schema_object, path, diagnostics)
    _ =>
      diagnostics.push(
        diagnostic(
          path,
          InvalidSchemaBoundary,
          "schema must be a boolean or object",
        ),
      )
  }
}

///|
/// Lint object-form schema keywords and recurse into child schemas.
fn lint_schema_object(
  schema : Map[String, Json],
  path : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  lint_type_keyword(schema, path, diagnostics)
  lint_enum_keyword(schema, path, diagnostics)
  lint_boolean_keyword(schema, "uniqueItems", path, diagnostics)
  lint_integer_bound_pair(schema, "minLength", "maxLength", path, diagnostics)
  lint_integer_bound_pair(schema, "minItems", "maxItems", path, diagnostics)
  lint_integer_bound_pair(
    schema, "minProperties", "maxProperties", path, diagnostics,
  )
  lint_number_bound_pair(schema, "minimum", "maximum", path, diagnostics)
  lint_number_bound_pair(
    schema, "exclusiveMinimum", "exclusiveMaximum", path, diagnostics,
  )
  lint_required_keyword(schema, path, diagnostics)
  lint_properties_keyword(schema, path, diagnostics)
  lint_additional_properties(schema, path, diagnostics)
  lint_items_keyword(schema, path, diagnostics)
  lint_composition_keyword(schema, "allOf", path, diagnostics)
  lint_composition_keyword(schema, "anyOf", path, diagnostics)
  lint_composition_keyword(schema, "oneOf", path, diagnostics)
  match schema.get("not") {
    None => ()
    Some(child_schema) => lint_schema(child_schema, path + ".not", diagnostics)
  }
}

///|
/// Check a boolean-only schema keyword without imposing a value policy.
fn lint_boolean_keyword(
  schema : Map[String, Json],
  keyword : String,
  path : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  match schema.get(keyword) {
    None | Some(True) | Some(False) => ()
    Some(_) =>
      diagnostics.push(
        diagnostic(
          path + "." + keyword,
          InvalidSchemaBoundary,
          keyword + " must be a boolean",
        ),
      )
  }
}

///|
/// Check primitive type declarations without evaluating a value.
fn lint_type_keyword(
  schema : Map[String, Json],
  path : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  match schema.get("type") {
    None => ()
    Some(String(type_name)) =>
      if !known_schema_type(type_name) {
        diagnostics.push(
          diagnostic(
            path + ".type",
            InvalidSchemaBoundary,
            "schema type is not supported",
          ),
        )
      }
    Some(Array(type_values)) => {
      if type_values.length() == 0 {
        diagnostics.push(
          diagnostic(
            path + ".type",
            InvalidSchemaBoundary,
            "schema type array cannot be empty",
          ),
        )
      }
      for index, type_value in type_values {
        match type_value {
          String(type_name) =>
            if !known_schema_type(type_name) {
              diagnostics.push(
                diagnostic(
                  path + ".type[" + index.to_string() + "]",
                  InvalidSchemaBoundary,
                  "schema type is not supported",
                ),
              )
            }
          _ =>
            diagnostics.push(
              diagnostic(
                path + ".type[" + index.to_string() + "]",
                InvalidSchemaBoundary,
                "schema type array must contain strings",
              ),
            )
        }
      }
    }
    Some(_) =>
      diagnostics.push(
        diagnostic(
          path + ".type",
          InvalidSchemaBoundary,
          "schema type must be a string or array",
        ),
      )
  }
}

///|
/// Check that enum is a non-empty array and contains JSON values.
fn lint_enum_keyword(
  schema : Map[String, Json],
  path : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  match schema.get("enum") {
    None => ()
    Some(Array(values)) =>
      if values.length() == 0 {
        diagnostics.push(
          diagnostic(
            path + ".enum",
            InvalidSchemaBoundary,
            "enum must contain at least one value",
          ),
        )
      }
    Some(_) =>
      diagnostics.push(
        diagnostic(
          path + ".enum",
          InvalidSchemaBoundary,
          "enum must be an array",
        ),
      )
  }
}

///|
/// Validate integer bounds and report contradictions at the lower bound.
fn lint_integer_bound_pair(
  schema : Map[String, Json],
  minimum_keyword : String,
  maximum_keyword : String,
  path : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  let minimum = lint_nonnegative_integer(
    schema, minimum_keyword, path, diagnostics,
  )
  let maximum = lint_nonnegative_integer(
    schema, maximum_keyword, path, diagnostics,
  )
  match (minimum, maximum) {
    (Some(minimum_value), Some(maximum_value)) if minimum_value > maximum_value =>
      diagnostics.push(
        diagnostic(
          path + "." + minimum_keyword,
          InvalidSchemaBoundary,
          minimum_keyword + " must not exceed " + maximum_keyword,
        ),
      )
    _ => ()
  }
}

///|
/// Validate numeric bounds and report contradictions at the lower bound.
fn lint_number_bound_pair(
  schema : Map[String, Json],
  minimum_keyword : String,
  maximum_keyword : String,
  path : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  let minimum = lint_number(schema, minimum_keyword, path, diagnostics)
  let maximum = lint_number(schema, maximum_keyword, path, diagnostics)
  match (minimum, maximum) {
    (Some(minimum_value), Some(maximum_value)) if minimum_value > maximum_value =>
      diagnostics.push(
        diagnostic(
          path + "." + minimum_keyword,
          InvalidSchemaBoundary,
          minimum_keyword + " must not exceed " + maximum_keyword,
        ),
      )
    _ => ()
  }
}

///|
/// Read a non-negative integer keyword while emitting malformed-value errors.
fn lint_nonnegative_integer(
  schema : Map[String, Json],
  keyword : String,
  path : String,
  diagnostics : Array[Diagnostic],
) -> Int? {
  match schema.get(keyword) {
    None => None
    Some(Number(value, ..)) => {
      let integer = value.to_int()
      if value != integer.to_double() || integer < 0 {
        diagnostics.push(
          diagnostic(
            path + "." + keyword,
            InvalidSchemaBoundary,
            keyword + " must be a non-negative integer",
          ),
        )
        None
      } else {
        Some(integer)
      }
    }
    Some(_) => {
      diagnostics.push(
        diagnostic(
          path + "." + keyword,
          InvalidSchemaBoundary,
          keyword + " must be a non-negative integer",
        ),
      )
      None
    }
  }
}

///|
/// Read a numeric keyword while emitting malformed-value errors.
fn lint_number(
  schema : Map[String, Json],
  keyword : String,
  path : String,
  diagnostics : Array[Diagnostic],
) -> Double? {
  match schema.get(keyword) {
    None => None
    Some(Number(value, ..)) => Some(value)
    Some(_) => {
      diagnostics.push(
        diagnostic(
          path + "." + keyword,
          InvalidSchemaBoundary,
          keyword + " must be a number",
        ),
      )
      None
    }
  }
}

///|
/// Validate required names and duplicate required entries.
fn lint_required_keyword(
  schema : Map[String, Json],
  path : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  match schema.get("required") {
    None => ()
    Some(Array(names)) =>
      for index, value in names {
        match value {
          String(name) =>
            for previous_index in 0..<index {
              match names[previous_index] {
                String(previous_name) if previous_name == name =>
                  diagnostics.push(
                    diagnostic(
                      path + ".required[" + index.to_string() + "]",
                      InvalidSchemaBoundary,
                      "required property names must be unique",
                    ),
                  )
                _ => ()
              }
            }
          _ =>
            diagnostics.push(
              diagnostic(
                path + ".required[" + index.to_string() + "]",
                InvalidSchemaBoundary,
                "required must contain strings",
              ),
            )
        }
      }
    Some(_) =>
      diagnostics.push(
        diagnostic(
          path + ".required",
          InvalidSchemaBoundary,
          "required must be an array",
        ),
      )
  }
}

///|
/// Recurse into an object-form properties map.
fn lint_properties_keyword(
  schema : Map[String, Json],
  path : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  match schema.get("properties") {
    None => ()
    Some(Object(properties)) =>
      for name, property_schema in properties {
        lint_schema(property_schema, path + ".properties." + name, diagnostics)
      }
    Some(_) =>
      diagnostics.push(
        diagnostic(
          path + ".properties",
          InvalidSchemaBoundary,
          "properties must be an object",
        ),
      )
  }
}

///|
/// Check additionalProperties shape; object values are recursively linted.
fn lint_additional_properties(
  schema : Map[String, Json],
  path : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  match schema.get("additionalProperties") {
    None | Some(True) | Some(False) => ()
    Some(Object(additional_schema)) =>
      lint_schema(
        Json::object(additional_schema),
        path + ".additionalProperties",
        diagnostics,
      )
    Some(_) =>
      diagnostics.push(
        diagnostic(
          path + ".additionalProperties",
          InvalidSchemaBoundary,
          "additionalProperties must be a boolean or object",
        ),
      )
  }
}

///|
/// Check and recurse into a single item schema; tuple arrays are explicit.
fn lint_items_keyword(
  schema : Map[String, Json],
  path : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  match schema.get("items") {
    None => ()
    Some(Array(_)) =>
      diagnostics.push(
        diagnostic(
          path + ".items",
          InvalidSchemaBoundary,
          "tuple-style items arrays are not supported",
        ),
      )
    Some(item_schema) => lint_schema(item_schema, path + ".items", diagnostics)
  }
}

///|
/// Ensure composition keywords have children and recurse into each branch.
fn lint_composition_keyword(
  schema : Map[String, Json],
  keyword : String,
  path : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  match schema.get(keyword) {
    None => ()
    Some(Array(schemas)) => {
      if schemas.length() == 0 {
        diagnostics.push(
          diagnostic(
            path + "." + keyword,
            InvalidSchemaBoundary,
            keyword + " must contain at least one schema",
          ),
        )
      }
      for index, child_schema in schemas {
        lint_schema(
          child_schema,
          path + "." + keyword + "[" + index.to_string() + "]",
          diagnostics,
        )
      }
    }
    Some(_) =>
      diagnostics.push(
        diagnostic(
          path + "." + keyword,
          InvalidSchemaBoundary,
          keyword + " must be an array",
        ),
      )
  }
}
