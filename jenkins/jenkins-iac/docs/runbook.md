# SonarQube Runbook

## Check Service

```bash
sudo systemctl status sonarqube
```

## View Logs

```bash
sudo journalctl -u sonarqube -f
```

## Restart Service

```bash
sudo systemctl restart sonarqube
```

## Verify Scanner

```bash
sonar-scanner -v
```

## Access UI

```text
http://SERVER_IP_OR_DOMAIN:9000
```
