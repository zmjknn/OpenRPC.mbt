///|
/// Validate a JSON value against the supported OpenRPC Schema subset.
///
/// The validator is deliberately pure: it does not resolve references, load
/// files, coerce values, or perform network I/O. A schema may be a boolean
/// schema or an object containing the supported JSON Schema keywords.
pub fn validate_schema(
  value : Json,
  schema : Json,
) -> Result[Unit, Array[Diagnostic]] {
  validate_schema_at(value, schema, "$")
}

///|
fn validate_schema_at(
  value : Json,
  schema : Json,
  path : String,
) -> Result[Unit, Array[Diagnostic]] {
  match schema {
    True => Ok(())
    False => schema_violation(path, "boolean schema rejects the value")
    Object(schema_object) => validate_schema_object(value, schema_object, path)
    _ => schema_definition_error(path, "schema must be a boolean or object")
  }
}

///|
fn validate_schema_object(
  value : Json,
  schema : Map[String, Json],
  path : String,
) -> Result[Unit, Array[Diagnostic]] {
  match validate_type_keyword(value, schema, path) {
    Err(diagnostics) => return Err(diagnostics)
    Ok(_) => ()
  }
  match validate_enum_keyword(value, schema, path) {
    Err(diagnostics) => return Err(diagnostics)
    Ok(_) => ()
  }
  match validate_const_keyword(value, schema, path) {
    Err(diagnostics) => return Err(diagnostics)
    Ok(_) => ()
  }
  match validate_all_of(value, schema, path) {
    Err(diagnostics) => return Err(diagnostics)
    Ok(_) => ()
  }
  match validate_any_of(value, schema, path) {
    Err(diagnostics) => return Err(diagnostics)
    Ok(_) => ()
  }
  match validate_one_of(value, schema, path) {
    Err(diagnostics) => return Err(diagnostics)
    Ok(_) => ()
  }
  match validate_not(value, schema, path) {
    Err(diagnostics) => return Err(diagnostics)
    Ok(_) => ()
  }
  match validate_string_keywords(value, schema, path) {
    Err(diagnostics) => return Err(diagnostics)
    Ok(_) => ()
  }
  match validate_number_keywords(value, schema, path) {
    Err(diagnostics) => return Err(diagnostics)
    Ok(_) => ()
  }
  match validate_array_keywords(value, schema, path) {
    Err(diagnostics) => return Err(diagnostics)
    Ok(_) => ()
  }
  validate_object_keywords(value, schema, path)
}

///|
fn validate_type_keyword(
  value : Json,
  schema : Map[String, Json],
  path : String,
) -> Result[Unit, Array[Diagnostic]] {
  match schema.get("type") {
    None => Ok(())
    Some(String(type_name)) => {
      if !known_schema_type(type_name) {
        return schema_definition_error(
          path + ".type",
          "schema type is not supported",
        )
      }
      if !matches_schema_type(value, type_name) {
        return schema_violation(
          path,
          "value does not match the schema type " + type_name,
        )
      }
      Ok(())
    }
    Some(Array(type_values)) => {
      if type_values.length() == 0 {
        return schema_definition_error(
          path + ".type",
          "schema type array cannot be empty",
        )
      }
      let mut matched = false
      for type_value in type_values {
        guard type_value is String(type_name) else {
          return schema_definition_error(
            path + ".type",
            "schema type array must contain strings",
          )
        }
        if !known_schema_type(type_name) {
          return schema_definition_error(
            path + ".type",
            "schema type is not supported",
          )
        }
        if matches_schema_type(value, type_name) {
          matched = true
        }
      }
      if !matched {
        return schema_violation(path, "value does not match any schema type")
      }
      Ok(())
    }
    Some(_) =>
      schema_definition_error(
        path + ".type",
        "schema type must be a string or array",
      )
  }
}

///|
fn known_schema_type(type_name : String) -> Bool {
  match type_name {
    "null" | "boolean" | "object" | "array" | "number" | "integer" | "string" =>
      true
    _ => false
  }
}

///|
fn matches_schema_type(value : Json, type_name : String) -> Bool {
  match type_name {
    "null" => value is Null
    "boolean" => value is True || value is False
    "object" => value is Object(_)
    "array" => value is Array(_)
    "number" => value is Number(_, ..)
    "integer" => {
      guard value is Number(number, ..) else { return false }
      number.trunc() == number
    }
    "string" => value is String(_)
    _ => false
  }
}

///|
fn validate_enum_keyword(
  value : Json,
  schema : Map[String, Json],
  path : String,
) -> Result[Unit, Array[Diagnostic]] {
  match schema.get("enum") {
    None => Ok(())
    Some(Array(values)) => {
      if values.length() == 0 {
        return schema_definition_error(
          path + ".enum",
          "enum must contain at least one value",
        )
      }
      for candidate in values {
        if Json::equal(value, candidate) {
          return Ok(())
        }
      }
      schema_violation(path, "value is not included in enum")
    }
    Some(_) => schema_definition_error(path + ".enum", "enum must be an array")
  }
}

///|
fn validate_const_keyword(
  value : Json,
  schema : Map[String, Json],
  path : String,
) -> Result[Unit, Array[Diagnostic]] {
  match schema.get("const") {
    None => Ok(())
    Some(expected) =>
      if Json::equal(value, expected) {
        Ok(())
      } else {
        schema_violation(path, "value does not match const")
      }
  }
}

///|
fn validate_all_of(
  value : Json,
  schema : Map[String, Json],
  path : String,
) -> Result[Unit, Array[Diagnostic]] {
  match schema.get("allOf") {
    None => Ok(())
    Some(Array(schemas)) => {
      for child_schema in schemas {
        match validate_schema_at(value, child_schema, path) {
          Ok(_) => ()
          Err(diagnostics) => return Err(diagnostics)
        }
      }
      Ok(())
    }
    Some(_) =>
      schema_definition_error(path + ".allOf", "allOf must be an array")
  }
}

///|
fn validate_any_of(
  value : Json,
  schema : Map[String, Json],
  path : String,
) -> Result[Unit, Array[Diagnostic]] {
  match schema.get("anyOf") {
    None => Ok(())
    Some(Array(schemas)) => {
      for child_schema in schemas {
        match schema_accepts(value, child_schema, path) {
          Err(diagnostics) => return Err(diagnostics)
          Ok(true) => return Ok(())
          Ok(false) => ()
        }
      }
      schema_violation(path, "value does not satisfy anyOf")
    }
    Some(_) =>
      schema_definition_error(path + ".anyOf", "anyOf must be an array")
  }
}

///|
fn validate_one_of(
  value : Json,
  schema : Map[String, Json],
  path : String,
) -> Result[Unit, Array[Diagnostic]] {
  match schema.get("oneOf") {
    None => Ok(())
    Some(Array(schemas)) => {
      let mut matches = 0
      for child_schema in schemas {
        match schema_accepts(value, child_schema, path) {
          Err(diagnostics) => return Err(diagnostics)
          Ok(true) => matches = matches + 1
          Ok(false) => ()
        }
      }
      if matches == 1 {
        Ok(())
      } else {
        schema_violation(path, "value must satisfy exactly one oneOf schema")
      }
    }
    Some(_) =>
      schema_definition_error(path + ".oneOf", "oneOf must be an array")
  }
}

///|
fn validate_not(
  value : Json,
  schema : Map[String, Json],
  path : String,
) -> Result[Unit, Array[Diagnostic]] {
  match schema.get("not") {
    None => Ok(())
    Some(child_schema) =>
      match schema_accepts(value, child_schema, path) {
        Err(diagnostics) => Err(diagnostics)
        Ok(true) => schema_violation(path, "value must not satisfy not schema")
        Ok(false) => Ok(())
      }
  }
}

///|
fn schema_accepts(
  value : Json,
  schema : Json,
  path : String,
) -> Result[Bool, Array[Diagnostic]] {
  match validate_schema_at(value, schema, path) {
    Ok(_) => Ok(true)
    Err(diagnostics) => {
      for item in diagnostics {
        if item.code is UnsupportedSchema {
          return Err(diagnostics)
        }
      }
      Ok(false)
    }
  }
}

///|
fn validate_string_keywords(
  value : Json,
  schema : Map[String, Json],
  path : String,
) -> Result[Unit, Array[Diagnostic]] {
  guard value is String(text) else { return Ok(()) }
  let min_length = match read_nonnegative_integer(schema, "minLength", path) {
    Err(diagnostics) => return Err(diagnostics)
    Ok(value) => value
  }
  let max_length = match read_nonnegative_integer(schema, "maxLength", path) {
    Err(diagnostics) => return Err(diagnostics)
    Ok(value) => value
  }
  if min_length is Some(minimum) && text.length() < minimum {
    return schema_violation(path, "string is shorter than minLength")
  }
  if max_length is Some(maximum) && text.length() > maximum {
    return schema_violation(path, "string is longer than maxLength")
  }
  Ok(())
}

///|
fn validate_number_keywords(
  value : Json,
  schema : Map[String, Json],
  path : String,
) -> Result[Unit, Array[Diagnostic]] {
  guard value is Number(number, ..) else { return Ok(()) }
  let minimum = match read_number(schema, "minimum", path) {
    Err(diagnostics) => return Err(diagnostics)
    Ok(value) => value
  }
  let maximum = match read_number(schema, "maximum", path) {
    Err(diagnostics) => return Err(diagnostics)
    Ok(value) => value
  }
  let exclusive_minimum = match read_number(schema, "exclusiveMinimum", path) {
    Err(diagnostics) => return Err(diagnostics)
    Ok(value) => value
  }
  let exclusive_maximum = match read_number(schema, "exclusiveMaximum", path) {
    Err(diagnostics) => return Err(diagnostics)
    Ok(value) => value
  }
  if minimum is Some(bound) && number < bound {
    return schema_violation(path, "number is below minimum")
  }
  if maximum is Some(bound) && number > bound {
    return schema_violation(path, "number is above maximum")
  }
  if exclusive_minimum is Some(bound) && number <= bound {
    return schema_violation(path, "number does not exceed exclusiveMinimum")
  }
  if exclusive_maximum is Some(bound) && number >= bound {
    return schema_violation(path, "number is not below exclusiveMaximum")
  }
  Ok(())
}

///|
fn validate_array_keywords(
  value : Json,
  schema : Map[String, Json],
  path : String,
) -> Result[Unit, Array[Diagnostic]] {
  guard value is Array(values) else { return Ok(()) }
  let min_items = match read_nonnegative_integer(schema, "minItems", path) {
    Err(diagnostics) => return Err(diagnostics)
    Ok(value) => value
  }
  let max_items = match read_nonnegative_integer(schema, "maxItems", path) {
    Err(diagnostics) => return Err(diagnostics)
    Ok(value) => value
  }
  if min_items is Some(minimum) && values.length() < minimum {
    return schema_violation(path, "array has fewer items than minItems")
  }
  if max_items is Some(maximum) && values.length() > maximum {
    return schema_violation(path, "array has more items than maxItems")
  }
  match schema.get("uniqueItems") {
    Some(True) =>
      for index, value in values {
        for previous_index in 0..<index {
          if Json::equal(value, values[previous_index]) {
            return schema_violation(path, "array items must be unique")
          }
        }
      }
    Some(False) | None => ()
    Some(_) =>
      return schema_definition_error(
        path + ".uniqueItems",
        "uniqueItems must be a boolean",
      )
  }
  match schema.get("items") {
    None => Ok(())
    Some(Array(_)) =>
      schema_definition_error(
        path + ".items",
        "tuple-style items arrays are not supported",
      )
    Some(item_schema) => {
      for index, item in values {
        match
          validate_schema_at(
            item,
            item_schema,
            path + "[" + index.to_string() + "]",
          ) {
          Ok(_) => ()
          Err(diagnostics) => return Err(diagnostics)
        }
      }
      Ok(())
    }
  }
}

///|
fn validate_object_keywords(
  value : Json,
  schema : Map[String, Json],
  path : String,
) -> Result[Unit, Array[Diagnostic]] {
  guard value is Object(properties) else { return Ok(()) }
  let min_properties = match
    read_nonnegative_integer(schema, "minProperties", path) {
    Err(diagnostics) => return Err(diagnostics)
    Ok(value) => value
  }
  let max_properties = match
    read_nonnegative_integer(schema, "maxProperties", path) {
    Err(diagnostics) => return Err(diagnostics)
    Ok(value) => value
  }
  if min_properties is Some(minimum) && properties.length() < minimum {
    return schema_violation(
      path, "object has fewer properties than minProperties",
    )
  }
  if max_properties is Some(maximum) && properties.length() > maximum {
    return schema_violation(
      path, "object has more properties than maxProperties",
    )
  }
  let property_schemas : Map[String, Json] = match schema.get("properties") {
    None => Map([])
    Some(Object(value)) => value
    Some(_) =>
      return schema_definition_error(
        path + ".properties",
        "properties must be an object",
      )
  }
  match schema.get("required") {
    None => ()
    Some(Array(required_names)) =>
      for required_value in required_names {
        guard required_value is String(name) else {
          return schema_definition_error(
            path + ".required",
            "required must contain strings",
          )
        }
        if properties.get(name) is None {
          return schema_violation(
            path + "." + name,
            "required property is missing",
          )
        }
      }
    Some(_) =>
      return schema_definition_error(
        path + ".required",
        "required must be an array",
      )
  }
  for name, property_value in properties {
    match property_schemas.get(name) {
      Some(property_schema) =>
        match
          validate_schema_at(property_value, property_schema, path + "." + name) {
          Ok(_) => ()
          Err(diagnostics) => return Err(diagnostics)
        }
      None =>
        match schema.get("additionalProperties") {
          None | Some(True) => ()
          Some(False) =>
            return schema_violation(
              path + "." + name,
              "additional property is not allowed",
            )
          Some(additional_schema) =>
            match
              validate_schema_at(
                property_value,
                additional_schema,
                path + "." + name,
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
fn read_number(
  schema : Map[String, Json],
  keyword : String,
  path : String,
) -> Result[Double?, Array[Diagnostic]] {
  match schema.get(keyword) {
    None => Ok(None)
    Some(Number(value, ..)) => Ok(Some(value))
    Some(_) =>
      Err([
        diagnostic(
          path + "." + keyword,
          UnsupportedSchema,
          keyword + " must be a number",
        ),
      ])
  }
}

///|
fn read_nonnegative_integer(
  schema : Map[String, Json],
  keyword : String,
  path : String,
) -> Result[Int?, Array[Diagnostic]] {
  match schema.get(keyword) {
    None => Ok(None)
    Some(Number(value, ..)) => {
      let integer = value.to_int()
      if value != integer.to_double() || integer < 0 {
        return Err([
          diagnostic(
            path + "." + keyword,
            UnsupportedSchema,
            keyword + " must be a non-negative integer",
          ),
        ])
      }
      Ok(Some(integer))
    }
    Some(_) =>
      Err([
        diagnostic(
          path + "." + keyword,
          UnsupportedSchema,
          keyword + " must be a non-negative integer",
        ),
      ])
  }
}

///|
fn schema_violation(
  path : String,
  message : String,
) -> Result[Unit, Array[Diagnostic]] {
  Err([diagnostic(path, SchemaViolation, message)])
}

///|
fn schema_definition_error(
  path : String,
  message : String,
) -> Result[Unit, Array[Diagnostic]] {
  Err([diagnostic(path, UnsupportedSchema, message)])
}
