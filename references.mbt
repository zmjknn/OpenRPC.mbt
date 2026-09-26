///|
/// Resolve one local JSON Pointer from the original document.
///
/// External references are rejected so resolution never reads files or
/// performs network requests. A pointer that targets another Reference Object
/// returns that object; callers may resolve its "$ref" separately.
pub fn Document::resolve_ref(
  self : Document,
  reference : String,
) -> Result[Json, Array[Diagnostic]] {
  resolve_json_pointer(self.source, reference, "$ref")
}

///|
/// Validate a JSON value against a schema after expanding its local references.
///
/// Circular schema references are reported instead of being silently treated
/// as empty schemas. The validator remains transport-independent and never
/// resolves a reference outside the original document.
pub fn Document::validate_schema(
  self : Document,
  value : Json,
  schema : Json,
) -> Result[Unit, Array[Diagnostic]] {
  validate_document_schema_at(self, value, schema, "$")
}

///|
/// Validate a method's named parameters, resolving local schema references.
pub fn Document::validate_named_params(
  self : Document,
  method_name : String,
  params : Map[String, Json],
) -> Result[Unit, Array[Diagnostic]] {
  let method_value = match self.find_method(method_name) {
    Some(value) => value
    None =>
      return Err([
        diagnostic(
          "$.method",
          UnknownMethod,
          "method is not declared by the document",
        ),
      ])
  }
  match validate_named_params(method_value.params, params, "$") {
    Err(diagnostics) => return Err(diagnostics)
    Ok(_) => ()
  }
  for parameter in method_value.params {
    match params.get(parameter.name) {
      None => ()
      Some(value) =>
        match
          validate_document_schema_at(
            self,
            value,
            parameter.schema,
            "$.params." + parameter.name,
          ) {
          Ok(_) => ()
          Err(diagnostics) => return Err(diagnostics)
        }
    }
  }
  Ok(())
}

///|
/// Validate positional method parameters with local schema reference support.
pub fn Document::validate_positional_params(
  self : Document,
  method_name : String,
  values : Array[Json],
) -> Result[Unit, Array[Diagnostic]] {
  let method_value = match self.find_method(method_name) {
    Some(value) => value
    None =>
      return Err([
        diagnostic(
          "$.method",
          UnknownMethod,
          "method is not declared by the document",
        ),
      ])
  }
  match validate_positional_params(method_value.params, values, "$") {
    Err(diagnostics) => return Err(diagnostics)
    Ok(_) => ()
  }
  for index, value in values {
    let parameter = method_value.params[index]
    match
      validate_document_schema_at(
        self,
        value,
        parameter.schema,
        "$.params[" + index.to_string() + "]",
      ) {
      Ok(_) => ()
      Err(diagnostics) => return Err(diagnostics)
    }
  }
  Ok(())
}

///|
/// Validate a method result against its declared schema with local references.
pub fn Document::validate_result(
  self : Document,
  method_name : String,
  value : Json,
) -> Result[Unit, Array[Diagnostic]] {
  let method_value = match self.find_method(method_name) {
    Some(value) => value
    None =>
      return Err([
        diagnostic(
          "$.method",
          UnknownMethod,
          "method is not declared by the document",
        ),
      ])
  }
  match method_value.result {
    None => Ok(())
    Some(result) =>
      validate_document_schema_at(self, value, result.schema, "$.result")
  }
}

///|
/// Validate every example pairing attached to a method.
///
/// Parameter examples are checked against the declared parameter order;
/// result examples are checked against the declared result schema.
pub fn Document::validate_examples(
  self : Document,
  method_name : String,
) -> Result[Unit, Array[Diagnostic]] {
  let method_value = match self.find_method(method_name) {
    Some(value) => value
    None =>
      return Err([
        diagnostic(
          "$.method",
          UnknownMethod,
          "method is not declared by the document",
        ),
      ])
  }
  for parameter_index, parameter in method_value.params {
    for example_index, example in parameter.examples {
      match
        validate_document_schema_at(
          self,
          example.value,
          parameter.schema,
          "$.methods." +
          method_name +
          ".params[" +
          parameter_index.to_string() +
          "].examples[" +
          example_index.to_string() +
          "].value",
        ) {
        Ok(_) => ()
        Err(diagnostics) => return Err(diagnostics)
      }
    }
  }
  match method_value.result {
    None => ()
    Some(result) =>
      for example_index, example in result.examples {
        match
          validate_document_schema_at(
            self,
            example.value,
            result.schema,
            "$.methods." +
            method_name +
            ".result.examples[" +
            example_index.to_string() +
            "].value",
          ) {
          Ok(_) => ()
          Err(diagnostics) => return Err(diagnostics)
        }
      }
  }
  for pairing_index, pairing in method_value.examples {
    let path = "$.methods." +
      method_name +
      ".examples[" +
      pairing_index.to_string() +
      "]"
    let values : Array[Json] = []
    for example in pairing.params {
      values.push(example.value)
    }
    match validate_positional_params(method_value.params, values, path) {
      Err(diagnostics) => return Err(diagnostics)
      Ok(_) => ()
    }
    for parameter_index, example in pairing.params {
      let parameter = method_value.params[parameter_index]
      match
        validate_document_schema_at(
          self,
          example.value,
          parameter.schema,
          path + ".params[" + parameter_index.to_string() + "].value",
        ) {
        Ok(_) => ()
        Err(diagnostics) => return Err(diagnostics)
      }
    }
    match pairing.result {
      None => ()
      Some(example) =>
        match method_value.result {
          None =>
            return Err([
              diagnostic(
                path + ".result",
                InvalidExamplePairing,
                "result example is present but the method has no result descriptor",
              ),
            ])
          Some(result) =>
            match
              validate_document_schema_at(
                self,
                example.value,
                result.schema,
                path + ".result.value",
              ) {
              Ok(_) => ()
              Err(diagnostics) => return Err(diagnostics)
            }
        }
    }
  }
  Ok(())
}

///|
/// Check all reference objects in the source document without rewriting it.
pub fn Document::lint_references(self : Document) -> Array[Diagnostic] {
  let diagnostics : Array[Diagnostic] = []
  lint_reference_json(self.source, "$", self.source, diagnostics)
  diagnostics
}

///|
fn validate_document_schema_at(
  document : Document,
  value : Json,
  schema : Json,
  path : String,
) -> Result[Unit, Array[Diagnostic]] {
  let expanded = match expand_schema_references(document, schema, path, []) {
    Ok(value) => value
    Err(diagnostics) => return Err(diagnostics)
  }
  validate_schema_at(value, expanded, path)
}

///|
fn expand_schema_references(
  document : Document,
  schema : Json,
  path : String,
  active : Array[String],
) -> Result[Json, Array[Diagnostic]] {
  match schema {
    Object(object) =>
      match object.get("$ref") {
        Some(String(reference)) => {
          for active_reference in active {
            if active_reference == reference {
              return Err([
                diagnostic(
                  path + ".$ref",
                  CircularReference,
                  "circular schema references cannot be evaluated by the subset validator",
                ),
              ])
            }
          }
          let target = match document.resolve_ref(reference) {
            Ok(value) => value
            Err(diagnostics) => return Err(diagnostics)
          }
          let next_active : Array[String] = []
          for active_reference in active {
            next_active.push(active_reference)
          }
          next_active.push(reference)
          let expanded_target = match
            expand_schema_references(document, target, path, next_active) {
            Ok(value) => value
            Err(diagnostics) => return Err(diagnostics)
          }
          let siblings : Map[String, Json] = Map([])
          for keyword, value in object {
            if keyword != "$ref" {
              siblings[keyword] = value
            }
          }
          if siblings.length() == 0 {
            Ok(expanded_target)
          } else {
            let expanded_siblings = match
              expand_schema_object_references(document, siblings, path, active) {
              Ok(value) => value
              Err(diagnostics) => return Err(diagnostics)
            }
            Ok(
              Json::object({
                "allOf": Json::array([expanded_target, expanded_siblings]),
              }),
            )
          }
        }
        Some(_) =>
          Err([
            diagnostic(path + ".$ref", InvalidField, "$ref must be a string"),
          ])
        None => expand_schema_object_references(document, object, path, active)
      }
    True | False => Ok(schema)
    _ =>
      Err([
        diagnostic(
          path,
          InvalidSchemaBoundary,
          "schema must be a boolean or object",
        ),
      ])
  }
}

///|
fn expand_schema_object_references(
  document : Document,
  schema : Map[String, Json],
  path : String,
  active : Array[String],
) -> Result[Json, Array[Diagnostic]] {
  let expanded : Map[String, Json] = Map([])
  for keyword, value in schema {
    match keyword {
      "properties" =>
        match value {
          Object(properties) =>
            match
              expand_schema_map(
                document,
                properties,
                path + ".properties",
                active,
              ) {
              Ok(value) => expanded[keyword] = value
              Err(diagnostics) => return Err(diagnostics)
            }
          _ => expanded[keyword] = value
        }
      "allOf" | "anyOf" | "oneOf" =>
        match value {
          Array(schemas) =>
            match
              expand_schema_array(
                document,
                schemas,
                path + "." + keyword,
                active,
              ) {
              Ok(value) => expanded[keyword] = Json::array(value)
              Err(diagnostics) => return Err(diagnostics)
            }
          _ => expanded[keyword] = value
        }
      "items" | "not" =>
        match value {
          Array(schemas) =>
            match
              expand_schema_array(
                document,
                schemas,
                path + "." + keyword,
                active,
              ) {
              Ok(value) => expanded[keyword] = Json::array(value)
              Err(diagnostics) => return Err(diagnostics)
            }
          _ =>
            match
              expand_schema_references(
                document,
                value,
                path + "." + keyword,
                active,
              ) {
              Ok(value) => expanded[keyword] = value
              Err(diagnostics) => return Err(diagnostics)
            }
        }
      _ => expanded[keyword] = value
    }
  }
  Ok(Json::object(expanded))
}

///|
fn expand_schema_map(
  document : Document,
  schemas : Map[String, Json],
  path : String,
  active : Array[String],
) -> Result[Json, Array[Diagnostic]] {
  let expanded : Map[String, Json] = Map([])
  for name, schema in schemas {
    match
      expand_schema_references(document, schema, path + "." + name, active) {
      Ok(value) => expanded[name] = value
      Err(diagnostics) => return Err(diagnostics)
    }
  }
  Ok(Json::object(expanded))
}

///|
fn expand_schema_array(
  document : Document,
  schemas : Array[Json],
  path : String,
  active : Array[String],
) -> Result[Array[Json], Array[Diagnostic]] {
  let expanded : Array[Json] = []
  for index, schema in schemas {
    match
      expand_schema_references(
        document,
        schema,
        path + "[" + index.to_string() + "]",
        active,
      ) {
      Ok(value) => expanded.push(value)
      Err(diagnostics) => return Err(diagnostics)
    }
  }
  Ok(expanded)
}

///|
fn lint_reference_json(
  value : Json,
  path : String,
  root : Json,
  diagnostics : Array[Diagnostic],
) -> Unit {
  match value {
    Object(object) => {
      match object.get("$ref") {
        None => ()
        Some(String(reference)) =>
          match resolve_reference_chain(root, reference, path, Map([])) {
            Ok(_) => ()
            Err(errors) =>
              for error in errors {
                diagnostics.push(error)
              }
          }
        Some(_) =>
          diagnostics.push(
            diagnostic(path + ".$ref", InvalidField, "$ref must be a string"),
          )
      }
      for key, child in object {
        lint_reference_json(child, path + "." + key, root, diagnostics)
      }
    }
    Array(values) =>
      for index, child in values {
        lint_reference_json(
          child,
          path + "[" + index.to_string() + "]",
          root,
          diagnostics,
        )
      }
    _ => ()
  }
}

///|
/// Resolve a reference object used in an OpenRPC field, following local
/// reference chains and reporting cycles with a diagnostic.
fn resolve_reference_value(
  root : Json,
  value : Json,
  path : String,
) -> Result[Json, Array[Diagnostic]] {
  match value {
    Object(object) =>
      match object.get("$ref") {
        Some(String(reference)) =>
          resolve_reference_chain(root, reference, path, Map([]))
        Some(_) =>
          Err([
            diagnostic(path + ".$ref", InvalidField, "$ref must be a string"),
          ])
        None => Ok(value)
      }
    _ => Ok(value)
  }
}

///|
fn resolve_reference_chain(
  root : Json,
  reference : String,
  path : String,
  seen : Map[String, Bool],
) -> Result[Json, Array[Diagnostic]] {
  if seen.get(reference) is Some(_) {
    return Err([
      diagnostic(
        path + ".$ref",
        CircularReference,
        "reference chain contains a cycle",
      ),
    ])
  }
  seen[reference] = true
  let value = match resolve_json_pointer(root, reference, path + ".$ref") {
    Ok(value) => value
    Err(diagnostics) => return Err(diagnostics)
  }
  match value {
    Object(object) =>
      match object.get("$ref") {
        Some(String(next)) => resolve_reference_chain(root, next, path, seen)
        Some(_) =>
          Err([
            diagnostic(path + ".$ref", InvalidField, "$ref must be a string"),
          ])
        None => Ok(value)
      }
    _ => Ok(value)
  }
}

///|
fn resolve_json_pointer(
  root : Json,
  reference : String,
  path : String,
) -> Result[Json, Array[Diagnostic]] {
  if reference == "#" {
    return Ok(root)
  }
  if !reference.has_prefix("#/") {
    return Err([
      diagnostic(
        path,
        UnsupportedReference,
        "only local JSON Pointer references are supported",
      ),
    ])
  }
  let tokens : Array[String] = reference
    .split("/")
    .map(fn(token) { token.to_owned() })
    .collect()
  let mut current = root
  for token_index in 1..<tokens.length() {
    let token = match decode_pointer_token(tokens[token_index], path) {
      Ok(value) => value
      Err(diagnostics) => return Err(diagnostics)
    }
    current = match current {
      Object(object) =>
        match object.get(token) {
          Some(value) => value
          None =>
            return Err([
              diagnostic(
                path,
                UnresolvedReference,
                "local reference does not point to a document value",
              ),
            ])
        }
      Array(values) => {
        let index_value = @json.parse(token) catch {
          _ =>
            return Err([
              diagnostic(
                path,
                UnresolvedReference,
                "array reference token must be a canonical non-negative index",
              ),
            ])
        }
        let index = match index_value {
          Number(number, ..) => {
            let index = number.to_int()
            if index < 0 ||
              index.to_double() != number ||
              index.to_string() != token {
              return Err([
                diagnostic(
                  path,
                  UnresolvedReference,
                  "array reference token must be a canonical non-negative index",
                ),
              ])
            }
            index
          }
          _ =>
            return Err([
              diagnostic(
                path,
                UnresolvedReference,
                "array reference token must be a canonical non-negative index",
              ),
            ])
        }
        if index >= values.length() {
          return Err([
            diagnostic(
              path,
              UnresolvedReference,
              "local reference points beyond the end of an array",
            ),
          ])
        }
        values[index]
      }
      _ =>
        return Err([
          diagnostic(
            path,
            UnresolvedReference,
            "local reference traverses a primitive JSON value",
          ),
        ])
    }
  }
  Ok(current)
}

///|
fn decode_pointer_token(
  token : String,
  path : String,
) -> Result[String, Array[Diagnostic]] {
  let source = token.to_array()
  let output : Array[Char] = []
  let mut index = 0
  while index < source.length() {
    if source[index] == '~' {
      if index + 1 >= source.length() {
        return Err([
          diagnostic(
            path,
            UnsupportedReference,
            "JSON Pointer token has an incomplete escape",
          ),
        ])
      }
      match source[index + 1] {
        '0' => output.push('~')
        '1' => output.push('/')
        _ =>
          return Err([
            diagnostic(
              path,
              UnsupportedReference,
              "JSON Pointer tokens only escape tilde as ~0 and slash as ~1",
            ),
          ])
      }
      index = index + 2
    } else {
      output.push(source[index])
      index = index + 1
    }
  }
  Ok(String::from_array(output))
}
