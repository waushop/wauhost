# unifi

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 7.1.68](https://img.shields.io/badge/AppVersion-7.1.68-informational?style=flat-square)

UniFi Network Controller Helm Chart

**Homepage:** <https://www.ui.com/>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| wauhost | <siim@waushop.ee> |  |

## Source Code

* <https://github.com/k8s-at-home/charts>

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| autoscaling.enabled | bool | `false` |  |
| autoscaling.maxReplicas | int | `1` |  |
| autoscaling.minReplicas | int | `1` |  |
| autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| env.JVM_INIT_HEAP_SIZE | string | `""` |  |
| env.JVM_MAX_HEAP_SIZE | string | `"1024M"` |  |
| env.RUNAS_UID0 | string | `"false"` |  |
| env.TZ | string | `"UTC"` |  |
| env.UNIFI_GID | string | `"999"` |  |
| env.UNIFI_STDOUT | string | `"true"` |  |
| env.UNIFI_UID | string | `"999"` |  |
| fullnameOverride | string | `""` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"jacobalberty/unifi"` |  |
| image.tag | string | `"v7.1.68"` |  |
| ingress.main.annotations."cert-manager.io/cluster-issuer" | string | `"letsencrypt"` |  |
| ingress.main.annotations."traefik.ingress.kubernetes.io/router.tls" | string | `"true"` |  |
| ingress.main.enabled | bool | `true` |  |
| ingress.main.hosts[0].host | string | `"controller.waushop.ee"` |  |
| ingress.main.hosts[0].paths[0].path | string | `"/"` |  |
| ingress.main.hosts[0].paths[0].pathType | string | `"Prefix"` |  |
| ingress.main.tls[0].hosts[0] | string | `"controller.waushop.ee"` |  |
| ingress.main.tls[0].secretName | string | `"controller-tls"` |  |
| livenessProbe.failureThreshold | int | `3` |  |
| livenessProbe.httpGet.path | string | `"/status"` |  |
| livenessProbe.httpGet.port | int | `8080` |  |
| livenessProbe.initialDelaySeconds | int | `30` |  |
| livenessProbe.periodSeconds | int | `10` |  |
| livenessProbe.timeoutSeconds | int | `5` |  |
| nameOverride | string | `""` |  |
| networkPolicy.egress | list | `[]` |  |
| networkPolicy.enabled | bool | `false` |  |
| networkPolicy.ingress | list | `[]` |  |
| nodeSelector | object | `{}` |  |
| persistence.data.annotations | object | `{}` |  |
| persistence.data.enabled | bool | `true` |  |
| persistence.data.size | string | `"20Gi"` |  |
| persistence.data.storageClass | string | `""` |  |
| podAnnotations | object | `{}` |  |
| podDisruptionBudget.enabled | bool | `false` |  |
| podDisruptionBudget.minAvailable | int | `1` |  |
| podLabels | object | `{}` |  |
| podSecurityContext.fsGroup | int | `999` |  |
| readinessProbe.failureThreshold | int | `3` |  |
| readinessProbe.httpGet.path | string | `"/status"` |  |
| readinessProbe.httpGet.port | int | `8080` |  |
| readinessProbe.initialDelaySeconds | int | `10` |  |
| readinessProbe.periodSeconds | int | `5` |  |
| readinessProbe.timeoutSeconds | int | `3` |  |
| resources.limits.cpu | string | `"1000m"` |  |
| resources.limits.memory | string | `"2Gi"` |  |
| resources.requests.cpu | string | `"500m"` |  |
| resources.requests.memory | string | `"1Gi"` |  |
| securityContext.allowPrivilegeEscalation | bool | `false` |  |
| securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| securityContext.readOnlyRootFilesystem | bool | `false` |  |
| securityContext.runAsGroup | int | `999` |  |
| securityContext.runAsNonRoot | bool | `true` |  |
| securityContext.runAsUser | int | `999` |  |
| service.main.ports.controller.enabled | bool | `true` |  |
| service.main.ports.controller.port | int | `8080` |  |
| service.main.ports.controller.protocol | string | `"TCP"` |  |
| service.main.ports.http.enabled | bool | `true` |  |
| service.main.ports.http.port | int | `8443` |  |
| service.main.ports.http.protocol | string | `"TCP"` |  |
| service.main.ports.portal-http.enabled | bool | `false` |  |
| service.main.ports.portal-http.port | int | `8880` |  |
| service.main.ports.portal-http.protocol | string | `"HTTP"` |  |
| service.main.ports.portal-https.enabled | bool | `false` |  |
| service.main.ports.portal-https.port | int | `8843` |  |
| service.main.ports.portal-https.protocol | string | `"TCP"` |  |
| service.main.ports.speedtest.enabled | bool | `true` |  |
| service.main.ports.speedtest.port | int | `6789` |  |
| service.main.ports.speedtest.protocol | string | `"TCP"` |  |
| service.main.type | string | `"ClusterIP"` |  |
| service.udp.enabled | bool | `false` |  |
| service.udp.loadBalancerIP | string | `""` |  |
| service.udp.ports.discovery.enabled | bool | `true` |  |
| service.udp.ports.discovery.port | int | `10001` |  |
| service.udp.ports.discovery.protocol | string | `"UDP"` |  |
| service.udp.ports.stun.enabled | bool | `true` |  |
| service.udp.ports.stun.port | int | `3478` |  |
| service.udp.ports.stun.protocol | string | `"UDP"` |  |
| service.udp.ports.syslog.enabled | bool | `true` |  |
| service.udp.ports.syslog.port | int | `5514` |  |
| service.udp.ports.syslog.protocol | string | `"UDP"` |  |
| service.udp.type | string | `"LoadBalancer"` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| startupProbe.failureThreshold | int | `30` |  |
| startupProbe.httpGet.path | string | `"/status"` |  |
| startupProbe.httpGet.port | int | `8080` |  |
| startupProbe.initialDelaySeconds | int | `30` |  |
| startupProbe.periodSeconds | int | `10` |  |
| startupProbe.timeoutSeconds | int | `5` |  |
| tolerations | list | `[]` |  |
| volumeMounts | list | `[]` |  |
| volumes | list | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.11.0](https://github.com/norwoodj/helm-docs/releases/v1.11.0)
