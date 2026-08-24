# Terraform asset layout

Place root-module assets under `assets/<root-module>/`. `assets/shared/` is reserved for inputs used by more than one module; it contains the official binary packaging Dockerfile.

- `assets/application/aws-load-balancer-controller-iam-policy.json` is the upstream AWS Load Balancer Controller v2.14.1 policy used by the application root module.
