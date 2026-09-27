///|
/// Severity assigned to a detected contract change.
pub enum ChangeImpact {
  Breaking
  Compatible
  Informational
}

///|
/// Kind of contract change detected by Document::diff.
pub enum ChangeKind {
  MethodAdded
  MethodRemoved
  ParameterAdded
  ParameterRemoved
  ParameterRequiredChanged
  ParameterOrderChanged
  ParameterSchemaChanged
  ResultAdded
  ResultRemoved
  ResultSchemaChanged
  ServerAdded
  ServerRemoved
  ServerChanged
  TagAdded
  TagRemoved
  ComponentAdded
  ComponentRemoved
  ComponentChanged
}

///|
/// One machine-readable change between two parsed OpenRPC documents.
pub struct ContractChange {
  path : String
  kind : ChangeKind
  impact : ChangeImpact
  summary : String
}

///|
/// Compare this document with a newer revision and return changes in source
/// declaration order. Schema changes are conservatively marked as breaking.
pub fn Document::diff(
  self : Document,
  next : Document,
) -> Array[ContractChange] {
  let changes : Array[ContractChange] = []
  for old_method in self.methods {
    let method_path = "$.methods." + old_method.name
    match next.find_method(old_method.name) {
      None =>
        push_contract_change(
          changes,
          method_path,
          MethodRemoved,
          Breaking,
          "method was removed",
        )
      Some(new_method) =>
        diff_method(old_method, new_method, method_path, changes)
    }
  }
  for new_method in next.methods {
    if self.find_method(new_method.name) is None {
      push_contract_change(
        changes,
        "$.methods." + new_method.name,
        MethodAdded,
        Compatible,
        "method was added",
      )
    }
  }
  diff_servers(self.servers, next.servers, changes)
  diff_tags(self.tags, next.tags, changes)
  diff_component_group(
    "schemas",
    self.components.schemas,
    next.components.schemas,
    changes,
  )
  diff_component_group(
    "examples",
    self.components.examples,
    next.components.examples,
    changes,
  )
  diff_component_group(
    "examplePairings",
    self.components.example_pairings,
    next.components.example_pairings,
    changes,
  )
  diff_component_group(
    "contentDescriptors",
    self.components.content_descriptors,
    next.components.content_descriptors,
    changes,
  )
  diff_component_group(
    "errors",
    self.components.errors,
    next.components.errors,
    changes,
  )
  diff_component_group(
    "links",
    self.components.links,
    next.components.links,
    changes,
  )
  diff_component_group(
    "tags",
    self.components.tags,
    next.components.tags,
    changes,
  )
  changes
}

///|
fn diff_method(
  old_method : Method,
  new_method : Method,
  method_path : String,
  changes : Array[ContractChange],
) -> Unit {
  for old_index, old_parameter in old_method.params {
    let parameter_path = method_path + ".params." + old_parameter.name
    match find_parameter_index(new_method.params, old_parameter.name) {
      None =>
        push_contract_change(
          changes,
          parameter_path,
          ParameterRemoved,
          Breaking,
          "parameter was removed",
        )
      Some(new_index) => {
        let new_parameter = new_method.params[new_index]
        if old_index != new_index {
          push_contract_change(
            changes,
            parameter_path,
            ParameterOrderChanged,
            Breaking,
            "parameter order changed",
          )
        }
        if old_parameter.required != new_parameter.required {
          let impact = if new_parameter.required {
            Breaking
          } else {
            Compatible
          }
          push_contract_change(
            changes,
            parameter_path + ".required",
            ParameterRequiredChanged,
            impact,
            "parameter requiredness changed",
          )
        }
        if !Json::equal(old_parameter.schema, new_parameter.schema) {
          push_contract_change(
            changes,
            parameter_path + ".schema",
            ParameterSchemaChanged,
            Breaking,
            "parameter schema changed",
          )
        }
      }
    }
  }
  for new_parameter in new_method.params {
    if find_parameter_index(old_method.params, new_parameter.name) is None {
      let impact = if new_parameter.required { Breaking } else { Compatible }
      push_contract_change(
        changes,
        method_path + ".params." + new_parameter.name,
        ParameterAdded,
        impact,
        "parameter was added",
      )
    }
  }
  match old_method.result {
    None =>
      match new_method.result {
        None => ()
        Some(_) =>
          push_contract_change(
            changes,
            method_path + ".result",
            ResultAdded,
            Informational,
            "result schema was added",
          )
      }
    Some(old_result) =>
      match new_method.result {
        None =>
          push_contract_change(
            changes,
            method_path + ".result",
            ResultRemoved,
            Breaking,
            "result descriptor was removed",
          )
        Some(new_result) =>
          if !Json::equal(old_result.schema, new_result.schema) {
            push_contract_change(
              changes,
              method_path + ".result.schema",
              ResultSchemaChanged,
              Breaking,
              "result schema changed",
            )
          }
      }
  }
}

///|
fn find_parameter_index(params : Array[Parameter], name : String) -> Int? {
  for index, parameter in params {
    if parameter.name == name {
      return Some(index)
    }
  }
  None
}

///|
fn diff_servers(
  old_servers : Array[Server],
  new_servers : Array[Server],
  changes : Array[ContractChange],
) -> Unit {
  for old_server in old_servers {
    match find_server_by_name(new_servers, old_server.name) {
      None =>
        push_contract_change(
          changes,
          "$.servers." + old_server.name,
          ServerRemoved,
          Breaking,
          "server was removed",
        )
      Some(new_server) =>
        if old_server.url != new_server.url {
          push_contract_change(
            changes,
            "$.servers." + old_server.name + ".url",
            ServerChanged,
            Breaking,
            "server URL changed",
          )
        }
    }
  }
  for new_server in new_servers {
    if find_server_by_name(old_servers, new_server.name) is None {
      push_contract_change(
        changes,
        "$.servers." + new_server.name,
        ServerAdded,
        Compatible,
        "server was added",
      )
    }
  }
}

///|
fn find_server_by_name(servers : Array[Server], name : String) -> Server? {
  for server in servers {
    if server.name == name {
      return Some(server)
    }
  }
  None
}

///|
fn diff_tags(
  old_tags : Array[Tag],
  new_tags : Array[Tag],
  changes : Array[ContractChange],
) -> Unit {
  for old_tag in old_tags {
    if find_tag_by_name(new_tags, old_tag.name) is None {
      push_contract_change(
        changes,
        "$.tags." + old_tag.name,
        TagRemoved,
        Informational,
        "tag was removed",
      )
    }
  }
  for new_tag in new_tags {
    if find_tag_by_name(old_tags, new_tag.name) is None {
      push_contract_change(
        changes,
        "$.tags." + new_tag.name,
        TagAdded,
        Informational,
        "tag was added",
      )
    }
  }
}

///|
fn find_tag_by_name(tags : Array[Tag], name : String) -> Tag? {
  for tag in tags {
    if tag.name == name {
      return Some(tag)
    }
  }
  None
}

///|
fn diff_component_group(
  section : String,
  old_values : Map[String, Json],
  new_values : Map[String, Json],
  changes : Array[ContractChange],
) -> Unit {
  for name, old_value in old_values {
    let path = "$.components." + section + "." + name
    match new_values.get(name) {
      None =>
        push_contract_change(
          changes,
          path,
          ComponentRemoved,
          Breaking,
          "component was removed",
        )
      Some(new_value) =>
        if !Json::equal(old_value, new_value) {
          push_contract_change(
            changes,
            path,
            ComponentChanged,
            Breaking,
            "component definition changed",
          )
        }
    }
  }
  for name, _new_value in new_values {
    if old_values.get(name) is None {
      push_contract_change(
        changes,
        "$.components." + section + "." + name,
        ComponentAdded,
        Compatible,
        "component was added",
      )
    }
  }
}

///|
fn push_contract_change(
  changes : Array[ContractChange],
  path : String,
  kind : ChangeKind,
  impact : ChangeImpact,
  summary : String,
) -> Unit {
  changes.push({ path, kind, impact, summary, })
}
