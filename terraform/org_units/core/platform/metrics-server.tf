data "http" "metrics_server_raw" {
  url = "https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.7.0/components.yaml"
}

data "kubectl_file_documents" "metrics_server_doc" {
  content = data.http.metrics_server_raw.response_body
}

resource "kubectl_manifest" "metrics_server" {
  for_each  = data.kubectl_file_documents.metrics_server_doc.manifests
  yaml_body = each.value
}