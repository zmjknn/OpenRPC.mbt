///|
test "the quickstart contract parses, lints, and builds a request" {
  let document = match Document::parse(quickstart_source()) {
    Ok(value) => value
    Err(_) => fail("the documented example contract should parse")
  }
  assert_eq(document.lint().length(), 0)
  let method_value = match document.find_method("inventory.get") {
    Some(value) => value
    None => fail("the documented example method should exist")
  }
  match method_value.build_request(7, { "id": "abc" }) {
    Ok(request) => assert_true(request is Object(_))
    Err(_) => fail("the documented example request should build")
  }
}

///|
test "the quickstart summary names the parsed method" {
  match quickstart_summary() {
    Ok(summary) => assert_true(summary.contains("inventory.get"))
    Err(_) => fail("the quickstart summary should not fail")
  }
}
