To make terraform work with the VPN, the providers need to be rebuilt with
CGO_ENABLED=1

## AWS Provider
```
go get github.com/terraform-providers/terraform-provider-aws
cd $GOPATH/src/github.com/terraform-providers/terraform-provider-aws
CGO_ENABLED=1 make build
cd -
cp $GOPATH/bin/terraform-provider-aws .terraform/plugins/darwin_amd64/terraform-provider-aws_v1.3.1_x4
terraform init
```
## Nomad Provider
```
go get github.com/terraform-providers/terraform-provider-nomad
cd $GOPATH/src/github.com/terraform-providers/terraform-provider-nomad
CGO_ENABLED=1 make build
cd -
cp $GOPATH/bin/terraform-provider-aws .terraform/plugins/darwin_amd64/terraform-provider-nomad_v1.0.0_x4
terraform init
```
