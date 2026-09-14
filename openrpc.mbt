pub struct Info {
  pub title : String
  pub version : String
}

pub struct Method {
  pub name : String
}

pub struct Document {
  pub openrpc : String
  pub info : Info
  pub methods : Array[Method]
}

pub enum ParseError {
  NotImplemented
}

pub fn Document::parse(_source : String) -> Result[Document, ParseError] {
  Err(NotImplemented)
}
