# Disaster Recovery

## Backup Local State

From a live root module:

```bash
terraform state pull > backup.tfstate
```

## Restore State

Use only when you are sure the backup is correct:

```bash
terraform state push backup.tfstate
```

## Stuck Lock

For remote backends, unlock only when no Terraform process is running:

```bash
terraform force-unlock LOCK_ID
```

## Server Recovery

If the server is rebuilt, update the `server_host` value if needed, then run:

```bash
terraform plan
terraform apply
```
