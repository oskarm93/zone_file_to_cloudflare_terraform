# zone_file_to_cloudflare_terraform
Given a zone file it will generate Terraform configuration files for Cloudflare.
Requires python and PowerShell.

```
./create_tf_file_from_zone_file.ps1 -ZoneFile 'zone.com.txt" -ZoneName 'zone.com' -TerraformOutputFile 'zone.com.tf'
```