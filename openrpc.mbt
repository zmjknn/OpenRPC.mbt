///|
pub struct Info {
  title : String
  version : String
}

///|
pub struct Parameter {
  name : String
  required : Bool
  schema : Json
}

///|
pub struct ResultDescriptor {
  name : String
  schema : Json
}

///|
pub struct Method {
  name : String
  params : Array[Parameter]
  result : ResultDescriptor?
}

///|
pub struct Document {
  openrpc : String
  info : Info
  methods : Array[Method]
}

///|
pub enum DiagnosticCode {
  InvalidJson
  ExpectedObject
  MissingField
  InvalidField
  UnsupportedVersion
  DuplicateMethod
  MissingParameter
  UnknownParameter
  TooManyParameters
  EmptyMethodName
  EmptyParameterName
  EmptyResultName
  DuplicateParameter
  OptionalBeforeRequired
  InvalidSchemaBoundary
  EmptyBatch
  UnknownMethod
  DuplicateRequestId
  SchemaViolation
  UnsupportedSchema
  InvalidResponse
  InvalidBatchResponse
  UnknownResponseId
  DuplicateResponseId
  MissingResponse
  ResponseIdMismatch
  InvalidRpcError
}

///|
pub struct Diagnostic {
  path : String
  code : DiagnosticCode
  message : String
}

///|
pub struct RpcError {
  code : Int
  message : String
  data : Json?
}

///|
pub enum RpcResponse {
  Result(Json)
  Error(RpcError)
}

///|
/// A response correlated with one of the calls in a JSON-RPC batch.
pub struct BatchResponse {
  id : Json
  method_name : String
  response : RpcResponse
}

///|
pub enum RequestParams {
  Named(Map[String, Json])
  Positional(Array[Json])
}

///|
pub struct BatchCall {
  id : Json
  method_name : String
  params : RequestParams
}

///|
pub fn RequestParams::named(params : Map[String, Json]) -> RequestParams {
  RequestParams::Named(params)
}

///|
pub fn RequestParams::positional(values : Array[Json]) -> RequestParams {
  RequestParams::Positional(values)
}

///|
pub fn BatchCall::new(
  id : Json,
  method_name : String,
  params : RequestParams,
) -> BatchCall {
  { id, method_name, params, }
}

///|
pub fn Document::parse(source : String) -> Result[Document, Array[Diagnostic]] {
  let value = @json.parse(source) catch {
    _ => return Err([diagnostic("$", InvalidJson, "source is not valid JSON")])
  }
  parse_document(value)
}

///|
pub fn Document::find_method(self : Document, name : String) -> Method? {
  for method_value in self.methods {
    if method_value.name == name {
      return Some(method_value)
    }
  }
  None
}

///|
pub fn Document::build_batch(
  self : Document,
  calls : Array[BatchCall],
) -> Result[Json, Array[Diagnostic]] {
  if calls.length() == 0 {
    return Err([
      diagnostic("$", EmptyBatch, "a JSON-RPC batch must contain a call"),
    ])
  }
  let requests : Array[Json] = []
  let ids : Array[Json] = []
  for index, call in calls {
    let call_path = "$[" + index.to_string() + "]"
    for previous_id in ids {
      if Json::equal(previous_id, call.id) {
        return Err([
          diagnostic(
            call_path + ".id",
            DuplicateRequestId,
            "request ids must be unique within a batch",
          ),
        ])
      }
    }
    ids.push(call.id)
    let method_value = match self.find_method(call.method_name) {
      Some(value) => value
      None =>
        return Err([
          diagnostic(
            call_path + ".method",
            UnknownMethod,
            "method is not declared by the document",
          ),
        ])
    }
    let request : Json = match call.params {
      RequestParams::Named(params) =>
        match validate_named_params(method_value.params, params, call_path) {
          Err(diagnostics) => return Err(diagnostics)
          Ok(_) =>
            {
              "jsonrpc": "2.0",
              "id": call.id,
              "method": method_value.name,
              "params": Json::object(params),
            }
        }
      RequestParams::Positional(values) =>
        match
          validate_positional_params(method_value.params, values, call_path) {
          Err(diagnostics) => return Err(diagnostics)
          Ok(_) =>
            {
              "jsonrpc": "2.0",
              "id": call.id,
              "method": method_value.name,
              "params": Json::array(values),
            }
        }
    }
    requests.push(request)
  }
  Ok(Json::array(requests))
}

///|
pub fn Method::build_request(
  self : Method,
  id : Json,
  params : Map[String, Json],
) -> Result[Json, Array[Diagnostic]] {
  match validate_named_params(self.params, params, "$") {
    Err(diagnostics) => Err(diagnostics)
    Ok(_) =>
      Ok({
        "jsonrpc": "2.0",
        "id": id,
        "method": self.name,
        "params": Json::object(params),
      })
  }
}

///|
pub fn Method::build_notification(
  self : Method,
  params : Map[String, Json],
) -> Result[Json, Array[Diagnostic]] {
  match validate_named_params(self.params, params, "$") {
    Err(diagnostics) => Err(diagnostics)
    Ok(_) =>
      Ok({
        "jsonrpc": "2.0",
        "method": self.name,
        "params": Json::object(params),
      })
  }
}

///|
pub fn Method::build_positional_request(
  self : Method,
  id : Json,
  values : Array[Json],
) -> Result[Json, Array[Diagnostic]] {
  match validate_positional_params(self.params, values, "$") {
    Err(diagnostics) => Err(diagnostics)
    Ok(_) =>
      Ok({
        "jsonrpc": "2.0",
        "id": id,
        "method": self.name,
        "params": Json::array(values),
      })
  }
}

///|
pub fn Method::build_positional_notification(
  self : Method,
  values : Array[Json],
) -> Result[Json, Array[Diagnostic]] {
  match validate_positional_params(self.params, values, "$") {
    Err(diagnostics) => Err(diagnostics)
    Ok(_) =>
      Ok({
        "jsonrpc": "2.0",
        "method": self.name,
        "params": Json::array(values),
      })
  }
}

///|
/// Validate one value against this parameter's declared schema.
///
/// Validation is explicit and opt-in. Request builders intentionally keep
/// their schema-agnostic behavior so callers can choose when validation is
/// appropriate for their transport or trust boundary.
pub fn Parameter::validate(
  self : Parameter,
  value : Json,
) -> Result[Unit, Array[Diagnostic]] {
  validate_schema_at(value, self.schema, "$.params." + self.name)
}

///|
/// Validate a result value against its declared schema.
pub fn ResultDescriptor::validate(
  self : ResultDescriptor,
  value : Json,
) -> Result[Unit, Array[Diagnostic]] {
  validate_schema_at(value, self.schema, "$.result")
}

///|
/// Validate named parameters against declarations and their schemas.
pub fn Method::validate_named_params(
  self : Method,
  params : Map[String, Json],
) -> Result[Unit, Array[Diagnostic]] {
  match validate_named_params(self.params, params, "$") {
    Err(diagnostics) => return Err(diagnostics)
    Ok(_) => ()
  }
  for parameter in self.params {
    match params.get(parameter.name) {
      None => ()
      Some(value) =>
        match
          validate_schema_at(
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
/// Validate positional parameters against declarations and their schemas.
pub fn Method::validate_positional_params(
  self : Method,
  values : Array[Json],
) -> Result[Unit, Array[Diagnostic]] {
  match validate_positional_params(self.params, values, "$") {
    Err(diagnostics) => return Err(diagnostics)
    Ok(_) => ()
  }
  for index, value in values {
    let parameter = self.params[index]
    match
      validate_schema_at(
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
/// Validate a result value when this method declares a result schema.
pub fn Method::validate_result(
  self : Method,
  value : Json,
) -> Result[Unit, Array[Diagnostic]] {
  match self.result {
    None => Ok(())
    Some(result) => result.validate(value)
  }
}

///|
fn validate_named_params(
  declarations : Array[Parameter],
  params : Map[String, Json],
  path_prefix : String,
) -> Result[Unit, Array[Diagnostic]] {
  for parameter in declarations {
    if parameter.required && params.get(parameter.name) is None {
      return Err([
        diagnostic(
          path_prefix + ".params." + parameter.name,
          MissingParameter,
          "required parameter is missing",
        ),
      ])
    }
  }
  for name, _value in params {
    let mut declared = false
    for parameter in declarations {
      if parameter.name == name {
        declared = true
        break
      }
    }
    if !declared {
      return Err([
        diagnostic(
          path_prefix + ".params." + name,
          UnknownParameter,
          "parameter is not declared by the method",
        ),
      ])
    }
  }
  Ok(())
}

///|
fn validate_positional_params(
  declarations : Array[Parameter],
  values : Array[Json],
  path_prefix : String,
) -> Result[Unit, Array[Diagnostic]] {
  if values.length() > declarations.length() {
    return Err([
      diagnostic(
        path_prefix + ".params",
        TooManyParameters,
        "too many positional parameters were provided",
      ),
    ])
  }
  for index, parameter in declarations {
    if index >= values.length() && parameter.required {
      return Err([
        diagnostic(
          path_prefix + ".params[" + index.to_string() + "]",
          MissingParameter,
          "required parameter is missing",
        ),
      ])
    }
  }
  Ok(())
}

///|
pub fn Method::decode_response(
  _self : Method,
  response : Json,
  request_id : Json,
) -> Result[RpcResponse, Array[Diagnostic]] {
  guard response is Object(response_object) else {
    return Err([
      diagnostic("$", InvalidResponse, "JSON-RPC response must be an object"),
    ])
  }
  match response_object.get("jsonrpc") {
    Some(String("2.0")) => ()
    Some(_) | None =>
      return Err([
        diagnostic(
          "$.jsonrpc",
          InvalidResponse,
          "response jsonrpc must be the string 2.0",
        ),
      ])
  }
  let response_id = match response_object.get("id") {
    Some(value) => value
    None =>
      return Err([
        diagnostic("$.id", InvalidResponse, "response id is required"),
      ])
  }
  if !Json::equal(response_id, request_id) {
    return Err([
      diagnostic(
        "$.id",
        ResponseIdMismatch,
        "response id does not match the request id",
      ),
    ])
  }
  let result = response_object.get("result")
  let error = response_object.get("error")
  if result is Some(_) && error is Some(_) {
    return Err([
      diagnostic(
        "$",
        InvalidResponse,
        "response must contain either result or error, not both",
      ),
    ])
  }
  match result {
    Some(value) => return Ok(RpcResponse::Result(value))
    None => ()
  }
  match error {
    Some(value) => decode_rpc_error(value)
    None =>
      Err([
        diagnostic(
          "$",
          InvalidResponse,
          "response must contain a result or error",
        ),
      ])
  }
}

///|
/// Decode and correlate a JSON-RPC batch response with its original calls.
///
/// Servers may return responses in any order. The returned array is reordered
/// to match `calls`, making downstream result handling deterministic while
/// preserving each method name and structured error payload.
pub fn Document::decode_batch_response(
  self : Document,
  response : Json,
  calls : Array[BatchCall],
) -> Result[Array[BatchResponse], Array[Diagnostic]] {
  if calls.length() == 0 {
    return Err([
      diagnostic(
        "$",
        EmptyBatch,
        "a batch response needs at least one expected call",
      ),
    ])
  }
  let response_values = match response {
    Array(values) => values
    _ =>
      return Err([
        diagnostic(
          "$",
          InvalidBatchResponse,
          "a batch response must be a JSON array",
        ),
      ])
  }
  if response_values.length() == 0 {
    return Err([
      diagnostic(
        "$",
        InvalidBatchResponse,
        "a batch response array cannot be empty",
      ),
    ])
  }
  let seen_ids : Array[Json] = []
  let decoded : Array[BatchResponse] = []
  for response_index, response_value in response_values {
    guard response_value is Object(response_object) else {
      return Err([
        diagnostic(
          "$[" + response_index.to_string() + "]",
          InvalidBatchResponse,
          "each batch response must be an object",
        ),
      ])
    }
    let response_id = match response_object.get("id") {
      Some(value) => value
      None =>
        return Err([
          diagnostic(
            "$[" + response_index.to_string() + "].id",
            InvalidBatchResponse,
            "each batch response must contain an id",
          ),
        ])
    }
    for previous_id in seen_ids {
      if Json::equal(previous_id, response_id) {
        return Err([
          diagnostic(
            "$[" + response_index.to_string() + "].id",
            DuplicateResponseId,
            "a batch response id may occur only once",
          ),
        ])
      }
    }
    seen_ids.push(response_id)
    let call_index : Int? = find_batch_call_index(calls, response_id)
    let call = match call_index {
      Some(index) => calls[index]
      None =>
        return Err([
          diagnostic(
            "$[" + response_index.to_string() + "].id",
            UnknownResponseId,
            "response id is not present in the original calls",
          ),
        ])
    }
    let method_value = match self.find_method(call.method_name) {
      Some(value) => value
      None =>
        return Err([
          diagnostic(
            "$[" + response_index.to_string() + "].method",
            UnknownMethod,
            "the original call method is not declared by the document",
          ),
        ])
    }
    let decoded_response = match
      method_value.decode_response(response_value, response_id) {
      Ok(value) => value
      Err(diagnostics) => return Err(diagnostics)
    }
    decoded.push({
      id: response_id,
      method_name: call.method_name,
      response: decoded_response,
    })
  }
  let ordered : Array[BatchResponse] = []
  for call_index, call in calls {
    let mut matched : BatchResponse? = None
    for value in decoded {
      if Json::equal(value.id, call.id) {
        matched = Some(value)
        break
      }
    }
    match matched {
      Some(value) => ordered.push(value)
      None =>
        return Err([
          diagnostic(
            "$.responses[" + call_index.to_string() + "]",
            MissingResponse,
            "the original call has no matching response",
          ),
        ])
    }
  }
  Ok(ordered)
}

///|
/// Find a call by JSON structural id equality.
fn find_batch_call_index(calls : Array[BatchCall], response_id : Json) -> Int? {
  for index, call in calls {
    if Json::equal(call.id, response_id) {
      return Some(index)
    }
  }
  None
}

///|
fn decode_rpc_error(value : Json) -> Result[RpcResponse, Array[Diagnostic]] {
  guard value is Object(error_object) else {
    return Err([
      diagnostic("$.error", InvalidRpcError, "error must be an object"),
    ])
  }
  let code = match error_object.get("code") {
    Some(Number(number, ..)) => {
      let integer = number.to_int()
      if integer.to_double() != number {
        return Err([
          diagnostic(
            "$.error.code",
            InvalidRpcError,
            "error code must be an integer",
          ),
        ])
      }
      integer
    }
    Some(_) =>
      return Err([
        diagnostic(
          "$.error.code",
          InvalidRpcError,
          "error code must be a number",
        ),
      ])
    None =>
      return Err([
        diagnostic("$.error.code", InvalidRpcError, "error code is required"),
      ])
  }
  let message = match error_object.get("message") {
    Some(String(value)) => value
    Some(_) =>
      return Err([
        diagnostic(
          "$.error.message",
          InvalidRpcError,
          "error message must be a string",
        ),
      ])
    None =>
      return Err([
        diagnostic(
          "$.error.message",
          InvalidRpcError,
          "error message is required",
        ),
      ])
  }
  Ok(RpcResponse::Error({ code, message, data: error_object.get("data"), }))
}

///|
fn parse_document(value : Json) -> Result[Document, Array[Diagnostic]] {
  guard value is Object(root) else {
    return Err([
      diagnostic("$", ExpectedObject, "OpenRPC document must be an object"),
    ])
  }
  let version = match root.get("openrpc") {
    Some(String(value)) => value
    Some(_) =>
      return Err([
        diagnostic("$.openrpc", InvalidField, "openrpc must be a string"),
      ])
    None =>
      return Err([
        diagnostic("$.openrpc", MissingField, "required field is missing"),
      ])
  }
  if !version.has_prefix("1.") {
    return Err([
      diagnostic(
        "$.openrpc",
        UnsupportedVersion,
        "only OpenRPC 1.x documents are supported",
      ),
    ])
  }
  let info = match root.get("info") {
    Some(Object(info)) =>
      match parse_info(info) {
        Ok(value) => value
        Err(diagnostics) => return Err(diagnostics)
      }
    Some(_) =>
      return Err([diagnostic("$.info", InvalidField, "info must be an object")])
    None =>
      return Err([
        diagnostic("$.info", MissingField, "required field is missing"),
      ])
  }
  let methods = match root.get("methods") {
    Some(Array(methods)) =>
      match parse_methods(methods) {
        Ok(value) => value
        Err(diagnostics) => return Err(diagnostics)
      }
    Some(_) =>
      return Err([
        diagnostic("$.methods", InvalidField, "methods must be an array"),
      ])
    None =>
      return Err([
        diagnostic("$.methods", MissingField, "required field is missing"),
      ])
  }
  Ok({ openrpc: version, info, methods, })
}

///|
fn parse_info(value : Map[String, Json]) -> Result[Info, Array[Diagnostic]] {
  let title = match value.get("title") {
    Some(String(value)) => value
    Some(_) =>
      return Err([
        diagnostic("$.info.title", InvalidField, "title must be a string"),
      ])
    None =>
      return Err([
        diagnostic("$.info.title", MissingField, "required field is missing"),
      ])
  }
  let version = match value.get("version") {
    Some(String(value)) => value
    Some(_) =>
      return Err([
        diagnostic("$.info.version", InvalidField, "version must be a string"),
      ])
    None =>
      return Err([
        diagnostic("$.info.version", MissingField, "required field is missing"),
      ])
  }
  Ok({ title, version, })
}

///|
fn parse_methods(
  values : Array[Json],
) -> Result[Array[Method], Array[Diagnostic]] {
  let methods : Array[Method] = []
  let names : Map[String, Bool] = Map([])
  for index, value in values {
    let method_path = "$.methods[" + index.to_string() + "]"
    guard value is Object(method_object) else {
      return Err([
        diagnostic(method_path, ExpectedObject, "each method must be an object"),
      ])
    }
    let name = match method_object.get("name") {
      Some(String(value)) => value
      Some(_) =>
        return Err([
          diagnostic(
            method_path + ".name",
            InvalidField,
            "method name must be a string",
          ),
        ])
      None =>
        return Err([
          diagnostic(
            method_path + ".name",
            MissingField,
            "required field is missing",
          ),
        ])
    }
    if names.get(name) is Some(_) {
      return Err([
        diagnostic(
          method_path + ".name",
          DuplicateMethod,
          "method names must be unique",
        ),
      ])
    }
    names[name] = true
    let params = match method_object.get("params") {
      None => []
      Some(Array(values)) =>
        match parse_parameters(values, method_path) {
          Ok(value) => value
          Err(diagnostics) => return Err(diagnostics)
        }
      Some(_) =>
        return Err([
          diagnostic(
            method_path + ".params",
            InvalidField,
            "params must be an array",
          ),
        ])
    }
    let result = match method_object.get("result") {
      None => None
      Some(Object(value)) =>
        match parse_result(value, method_path) {
          Ok(value) => Some(value)
          Err(diagnostics) => return Err(diagnostics)
        }
      Some(_) =>
        return Err([
          diagnostic(
            method_path + ".result",
            InvalidField,
            "result must be an object",
          ),
        ])
    }
    methods.push({ name, params, result, })
  }
  Ok(methods)
}

///|
fn parse_parameters(
  values : Array[Json],
  method_path : String,
) -> Result[Array[Parameter], Array[Diagnostic]] {
  let params : Array[Parameter] = []
  for index, value in values {
    let param_path = method_path + ".params[" + index.to_string() + "]"
    guard value is Object(parameter_object) else {
      return Err([
        diagnostic(
          param_path,
          ExpectedObject,
          "each parameter must be an object",
        ),
      ])
    }
    let name = match parameter_object.get("name") {
      Some(String(value)) => value
      Some(_) =>
        return Err([
          diagnostic(
            param_path + ".name",
            InvalidField,
            "parameter name must be a string",
          ),
        ])
      None =>
        return Err([
          diagnostic(
            param_path + ".name",
            MissingField,
            "required field is missing",
          ),
        ])
    }
    let required = match parameter_object.get("required") {
      None => false
      Some(True) => true
      Some(False) => false
      Some(_) =>
        return Err([
          diagnostic(
            param_path + ".required",
            InvalidField,
            "required must be a boolean",
          ),
        ])
    }
    let schema = match parameter_object.get("schema") {
      Some(value) => value
      None =>
        return Err([
          diagnostic(
            param_path + ".schema",
            MissingField,
            "required field is missing",
          ),
        ])
    }
    params.push({ name, required, schema, })
  }
  Ok(params)
}

///|
fn parse_result(
  value : Map[String, Json],
  method_path : String,
) -> Result[ResultDescriptor, Array[Diagnostic]] {
  let name = match value.get("name") {
    Some(String(value)) => value
    Some(_) =>
      return Err([
        diagnostic(
          method_path + ".result.name",
          InvalidField,
          "result name must be a string",
        ),
      ])
    None =>
      return Err([
        diagnostic(
          method_path + ".result.name",
          MissingField,
          "required field is missing",
        ),
      ])
  }
  let schema = match value.get("schema") {
    Some(value) => value
    None =>
      return Err([
        diagnostic(
          method_path + ".result.schema",
          MissingField,
          "required field is missing",
        ),
      ])
  }
  Ok({ name, schema, })
}

///|
fn diagnostic(
  path : String,
  code : DiagnosticCode,
  message : String,
) -> Diagnostic {
  { path, code, message, }
}
