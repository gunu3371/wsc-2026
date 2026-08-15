output "application_namespace" {
  description = "EKS 애플리케이션 namespace 이름"
  value       = kubernetes_namespace_v1.app.metadata[0].name
}

output "book_service_name" {
  description = "도서 애플리케이션 Kubernetes Service 이름"
  value       = kubernetes_service_v1.book.metadata[0].name
}
