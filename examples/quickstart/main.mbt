///|
fn main {
  match @openrpc.quickstart_summary() {
    Ok(summary) => println(summary)
    Err(diagnostics) =>
      for diagnostic in diagnostics {
        println(diagnostic.path + ": " + diagnostic.message)
      }
  }
}
