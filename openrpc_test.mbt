test "decodes the minimum OpenRPC document" {
  let source =
    #|{
    #|  "openrpc": "1.4.0",
    #|  "info": {"title": "Inventory", "version": "1.0.0"},
    #|  "methods": [{"name": "inventory.list"}]
    #|}
  match Document::parse(source) {
    Ok(document) => {
      assert_eq(document.openrpc, "1.4.0")
      assert_eq(document.info.title, "Inventory")
      assert_eq(document.methods.length(), 1)
      assert_eq(document.methods[0].name, "inventory.list")
    }
    Err(_) => fail("valid OpenRPC documents should be decoded")
  }
}
