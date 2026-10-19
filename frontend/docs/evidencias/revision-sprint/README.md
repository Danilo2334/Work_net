# Preparación de revisión — evidencias vigentes

19/10/2026, America/Bogota. Backend y QA: **Danilo2334**. Flutter e integración: **francisco3788**. Ejecución automatizada por agente; **revisión por otro integrante pendiente**. PR #146 en borrador y sin fusionar.

## Alcance comprobado y límite del Project

Se leyeron los criterios originales de HU001–HU010 (historias #2–#11) y tareas #29–#70. No se pudo leer el campo Sprint ni la vista Sprint Backlog: la credencial de Danilo carece de `read:project`. Por tanto, esta entrega documenta el trabajo autorizado y sus dependencias, **no acredita que todas estas tareas pertenezcan al Sprint 2 ni que el Sprint esté terminado**. No se modificaron criterios, cuerpos de issues, responsables, estados, Sprints, fechas ni hitos.

Las tareas con avances previos se reutilizaron; HU009/HU010 son dependencias indispensables de los estados empresariales del login. Se implementaron los resúmenes empresariales y administrativos, conservando explícitos los módulos futuros ausentes.

## Código y arquitectura

- Backend: [f9e4dea](https://github.com/Danilo2334/Work_net/commit/f9e4dea), Danilo, publicado en `feature/backend-sprint-2` y consolidado por fast-forward en `develop`. Migraciones aditivas, sin eliminar datos existentes.
- Incorporación en Flutter: [5b439b5](https://github.com/Danilo2334/Work_net/commit/5b439b5), conserva la autoría del backend.
- Flutter: [04e7e5c](https://github.com/Danilo2334/Work_net/commit/04e7e5c), Francisco, rama `frontend`.
- Contratos: [API empresarial](../../../../backend/accounts/COMPANY_API.md), [API de perfil](../../../../backend/candidate_dashboard/PROFILE_API.md).

Se separaron seis funcionalidades en `data`, `domain` y `presentation`: registro, acceso, cuenta, dashboard, perfil y empresa. Domain no depende de Flutter ni HTTP; Data interpreta respuestas y almacenamiento; Presentation administra estado de pantalla. `AppDependencies` compone los repositorios. `SessionLifecycle` concentra persistencia/rotación/logout y los casos de uso empresariales validan envío y decisiones. Se reutiliza el tema WorkNet, con colores compartidos centralizados, sin nuevas dependencias.

## Pruebas de esta fase

| Comprobación | Resultado realmente obtenido |
| --- | --- |
| `flutter analyze` | Sin incidencias |
| `flutter test` | 77 aprobadas |
| `flutter build web --dart-define=API_BASE_URL=http://127.0.0.1:8006/api/` | Compilación web correcta; se usa JS, no se acredita compatibilidad WASM |
| `python manage.py test accounts candidate_dashboard --noinput` | 103 aprobadas |
| `python manage.py check` | Sin incidencias |
| `python manage.py makemigrations --check --dry-run` | Sin cambios pendientes |
| Arranque QA con migraciones | Aplicadas a nueva SQLite aislada |
| API HTTP adicional y contraste SQLite | 49 casos aprobados; [informe](../../../../backend/docs/evidencias/revision-sprint/README.md) |
| Navegador/API | 50 casos aprobados y 22 capturas nuevas; [JSON sanitizado](resultados-qa.json) |

Chrome automatizado: escritorio 1440×1200 (1440×1800 para mostrar los complementos y logo completos) y móvil web 390×844. Flutter en localhost:55006 y Django en 127.0.0.1:8006, datos ficticios QA. La suite Django usa su propia base temporal; las comprobaciones HTTP/navegador usan otra SQLite en `.dart_tool`, nunca la base habitual. Los totales son conjuntos, no conteos por issue.

La traza `respuestas_api` del informe de navegador corresponde al último segmento reanudado de la automatización; los casos individuales acreditan el recorrido completo. El comprobador HTTP independiente enlazado conserva sus 49 casos. Persistencia y permisos se respaldan en API/base y pruebas, no solo en imágenes.

SMTP se mantuvo en MAILERS, Django 6.1.1. Falta `backend/.env` y no se comprobó recepción real. En esta fase los mensajes quedaron en archivos privados: se verificaron los enlaces locales y posterior acceso; **no se envió correo real ni se acreditó recepción en Gmail**. Los errores de envío se simularon en las pruebas Django.

## Tareas y pendiente propio

Todas conservan revisión humana pendiente. «Implementado» describe código y evidencia, no cierre ni aprobación.

| Tarea original | Responsable del registro | Avance y pendiente específico |
| --- | --- | --- |
| [#29 — TASK-HU001-01 Crear interfaz de registro en Flutter](https://github.com/Danilo2334/Work_net/issues/29) | francisco3788 | Registro: cuenta antes del rol; SMTP real pendiente; revisión pendiente |
| [#30 — TASK-HU001-02 Implementar usuario, roles y API de registro](https://github.com/Danilo2334/Work_net/issues/30) | Danilo2334 | Registro: cuenta antes del rol; SMTP real pendiente; revisión pendiente |
| [#31 — TASK-HU001-03 Implementar verificación de correo](https://github.com/Danilo2334/Work_net/issues/31) | Danilo2334 | Registro: cuenta antes del rol; SMTP real pendiente; revisión pendiente |
| [#32 — TASK-HU001-04 Integrar registro Flutter con Django](https://github.com/Danilo2334/Work_net/issues/32) | francisco3788 | Registro: cuenta antes del rol; SMTP real pendiente; revisión pendiente |
| [#33 — TASK-HU001-05 Probar criterios de aceptación de registro](https://github.com/Danilo2334/Work_net/issues/33) | Danilo2334 | Registro: cuenta antes del rol; SMTP real pendiente; revisión pendiente |
| [#34 — TASK-HU002-01 Crear pantalla de inicio de sesión en Flutter](https://github.com/Danilo2334/Work_net/issues/34) | francisco3788 | Acceso: sesión, destinos y estados empresariales reales; revisión pendiente |
| [#35 — TASK-HU002-02 Implementar autenticación y endpoint de login](https://github.com/Danilo2334/Work_net/issues/35) | Danilo2334 | Acceso: sesión, destinos y estados empresariales reales; revisión pendiente |
| [#36 — TASK-HU002-03 Implementar sesión y redirección por rol](https://github.com/Danilo2334/Work_net/issues/36) | francisco3788 | Acceso: sesión, destinos y estados empresariales reales; revisión pendiente |
| [#37 — TASK-HU002-04 Manejar estados especiales de empresa](https://github.com/Danilo2334/Work_net/issues/37) | francisco3788 | Acceso: sesión, destinos y estados empresariales reales; revisión pendiente |
| [#38 — TASK-HU002-05 Probar criterios de aceptación del login](https://github.com/Danilo2334/Work_net/issues/38) | Danilo2334 | Acceso: sesión, destinos y estados empresariales reales; revisión pendiente |
| [#39 — TASK-HU003-01 Crear pantallas de recuperación de contraseña](https://github.com/Danilo2334/Work_net/issues/39) | francisco3788 | Recuperación local completa; recepción SMTP pendiente; revisión pendiente |
| [#40 — TASK-HU003-02 Implementar tokens y correo de recuperación](https://github.com/Danilo2334/Work_net/issues/40) | Danilo2334 | Recuperación local completa; recepción SMTP pendiente; revisión pendiente |
| [#41 — TASK-HU003-03 Integrar recuperación Flutter-Django](https://github.com/Danilo2334/Work_net/issues/41) | francisco3788 | Recuperación local completa; recepción SMTP pendiente; revisión pendiente |
| [#42 — TASK-HU003-04 Probar recuperación y expiración](https://github.com/Danilo2334/Work_net/issues/42) | Danilo2334 | Recuperación local completa; recepción SMTP pendiente; revisión pendiente |
| [#43 — TASK-HU004-01 Crear interfaz de configuración de cuenta](https://github.com/Danilo2334/Work_net/issues/43) | francisco3788 | Configuración: revisión humana pendiente; revisión pendiente |
| [#44 — TASK-HU004-02 Implementar endpoints de configuración](https://github.com/Danilo2334/Work_net/issues/44) | Danilo2334 | Configuración: revisión humana pendiente; revisión pendiente |
| [#45 — TASK-HU004-03 Implementar preferencias de notificaciones](https://github.com/Danilo2334/Work_net/issues/45) | Danilo2334 | Configuración: revisión humana pendiente; revisión pendiente |
| [#46 — TASK-HU004-04 Integrar y probar configuración](https://github.com/Danilo2334/Work_net/issues/46) | Danilo2334 / francisco3788 | Configuración: revisión humana pendiente; revisión pendiente |
| [#47 — TASK-HU005-01 Diseñar Dashboard del Candidato](https://github.com/Danilo2334/Work_net/issues/47) | francisco3788 | Resumen real; accesos a módulos futuros pendientes; revisión pendiente |
| [#48 — TASK-HU005-02 Crear API resumen del candidato](https://github.com/Danilo2334/Work_net/issues/48) | Danilo2334 | Resumen real; accesos a módulos futuros pendientes; revisión pendiente |
| [#49 — TASK-HU005-03 Integrar datos reales en el dashboard](https://github.com/Danilo2334/Work_net/issues/49) | francisco3788 | Resumen real; accesos a módulos futuros pendientes; revisión pendiente |
| [#50 — TASK-HU005-04 Probar Dashboard del Candidato](https://github.com/Danilo2334/Work_net/issues/50) | Danilo2334 | Resumen real; accesos a módulos futuros pendientes; revisión pendiente |
| [#51 — TASK-HU006-01 Diseñar Dashboard de Empresa](https://github.com/Danilo2334/Work_net/issues/51) | francisco3788 | Métricas y postulaciones reales; gestión futura pendiente; revisión pendiente |
| [#52 — TASK-HU006-02 Crear API resumen de empresa](https://github.com/Danilo2334/Work_net/issues/52) | Danilo2334 | Métricas y postulaciones reales; gestión futura pendiente; revisión pendiente |
| [#53 — TASK-HU006-03 Integrar dashboard con datos reales](https://github.com/Danilo2334/Work_net/issues/53) | francisco3788 | Métricas y postulaciones reales; gestión futura pendiente; revisión pendiente |
| [#54 — TASK-HU006-04 Probar Dashboard de Empresa](https://github.com/Danilo2334/Work_net/issues/54) | Danilo2334 | Métricas y postulaciones reales; gestión futura pendiente; revisión pendiente |
| [#55 — TASK-HU007-01 Diseñar Dashboard de Administrador](https://github.com/Danilo2334/Work_net/issues/55) | francisco3788 | Métricas y validación; gestión de administradores pendiente; revisión pendiente |
| [#56 — TASK-HU007-02 Crear API de métricas administrativas](https://github.com/Danilo2334/Work_net/issues/56) | Danilo2334 | Métricas y validación; gestión de administradores pendiente; revisión pendiente |
| [#57 — TASK-HU007-03 Integrar avisos de nuevas empresas](https://github.com/Danilo2334/Work_net/issues/57) | francisco3788 | Métricas y validación; gestión de administradores pendiente; revisión pendiente |
| [#58 — TASK-HU007-04 Probar permisos del administrador](https://github.com/Danilo2334/Work_net/issues/58) | Danilo2334 | Métricas y validación; gestión de administradores pendiente; revisión pendiente |
| [#59 — TASK-HU008-01 Crear formulario de Perfil de Candidato](https://github.com/Danilo2334/Work_net/issues/59) | francisco3788 | Perfil propio y foto; consulta empresarial autorizada pendiente; revisión pendiente |
| [#60 — TASK-HU008-02 Crear modelos y API del perfil](https://github.com/Danilo2334/Work_net/issues/60) | Danilo2334 | Perfil propio y foto; consulta empresarial autorizada pendiente; revisión pendiente |
| [#61 — TASK-HU008-03 Integrar perfil y fotografía](https://github.com/Danilo2334/Work_net/issues/61) | francisco3788 | Perfil propio y foto; consulta empresarial autorizada pendiente; revisión pendiente |
| [#62 — TASK-HU008-04 Probar perfil de candidato](https://github.com/Danilo2334/Work_net/issues/62) | Danilo2334 | Perfil propio y foto; consulta empresarial autorizada pendiente; revisión pendiente |
| [#63 — TASK-HU009-01 Crear formulario de información empresarial](https://github.com/Danilo2334/Work_net/issues/63) | francisco3788 | Información empresarial, envío, complementos y persistencia; revisión pendiente |
| [#64 — TASK-HU009-02 Crear modelo y API empresarial](https://github.com/Danilo2334/Work_net/issues/64) | Danilo2334 | Información empresarial, envío, complementos y persistencia; revisión pendiente |
| [#65 — TASK-HU009-03 Integrar envío y pantalla de espera](https://github.com/Danilo2334/Work_net/issues/65) | francisco3788 | Información empresarial, envío, complementos y persistencia; revisión pendiente |
| [#66 — TASK-HU009-04 Probar registro empresarial](https://github.com/Danilo2334/Work_net/issues/66) | Danilo2334 | Información empresarial, envío, complementos y persistencia; revisión pendiente |
| [#67 — TASK-HU010-01 Crear vista de empresas pendientes](https://github.com/Danilo2334/Work_net/issues/67) | francisco3788 | Validación administrativa, motivos, reenvío y avisos; revisión pendiente |
| [#68 — TASK-HU010-02 Implementar aprobación/rechazo](https://github.com/Danilo2334/Work_net/issues/68) | Danilo2334 | Validación administrativa, motivos, reenvío y avisos; revisión pendiente |
| [#69 — TASK-HU010-03 Integrar validación y notificación](https://github.com/Danilo2334/Work_net/issues/69) | francisco3788 | Validación administrativa, motivos, reenvío y avisos; revisión pendiente |
| [#70 — TASK-HU010-04 Probar validación empresarial](https://github.com/Danilo2334/Work_net/issues/70) | Danilo2334 | Validación administrativa, motivos, reenvío y avisos; revisión pendiente |

## Casos del navegador y la API

| Caso | Tipo | Esperado | Obtenido |
| --- | --- | --- | --- |
| Registro Empresa: cuenta creada antes del selector | Navegador + API | 201 | 201 |
| Registro Empresa: rol persistido | Navegador + API | 200 | 200 |
| Verificación Empresa con enlace capturado localmente | API + correo a archivos | 200 | 200 |
| Verificación Empresa reutilizada es idempotente | API | 200 | 200 |
| Empresa nueva: Pendiente sin solicitud enviada | Navegador + API | {'state': 'pending', 'submitted': False} | {'state': 'pending', 'submitted': False} |
| Solicitud completa conserva datos y queda pendiente | Navegador + API | {'name': 'Empresa ficticia de revisión QA', 'state': 'pending', 'submitted': True} | {'name': 'Empresa ficticia de revisión QA', 'state': 'pending', 'submitted': True} |
| Empresa pendiente no entra al dashboard | API | 403 | 403 |
| Empresa no puede aprobar su propia solicitud | API | 403 | 403 |
| Empresa no puede asignar propietario desde el formulario | API | 400 | 400 |
| Logout de empresa pendiente revoca el token | Navegador + API | 401 | 401 |
| Administrador ve una solicitud pendiente real | Navegador + API | 1 | 1 |
| Rechazo sin motivo no se envía desde la pantalla | Navegador | True | True |
| Solicitud rechazada sale del listado pendiente | Navegador + API | 0 | 0 |
| Logout del administrador revoca el token | Navegador + API | 401 | 401 |
| Login de empresa rechazada muestra estado y motivo reales | Navegador + API | {'state': 'rejected', 'reason': 'Corrige la ubicación para identificar la sede.'} | {'state': 'rejected', 'reason': 'Corrige la ubicación para identificar la sede.'} |
| Corrección y reenvío persisten y vuelven a Pendiente | Navegador + API | {'location': 'Pasto · sede ficticia corregida', 'state': 'pending'} | {'location': 'Pasto · sede ficticia corregida', 'state': 'pending'} |
| Logout de empresa corregida revoca el token | Navegador + API | 401 | 401 |
| Aprobación administrativa retira la solicitud pendiente | Navegador + API | 0 | 0 |
| Decisión sobre versión obsoleta no sobrescribe aprobación | API | 409 | 409 |
| Logout del administrador tras aprobación revoca token | Navegador + API | 401 | 401 |
| Empresa aprobada recibe dashboard vacío real | Navegador + API | {'active_offers': 0, 'closed_offers': 0, 'applications': 0} | {'active_offers': 0, 'closed_offers': 0, 'applications': 0} |
| Empresa aprobada conserva decisión y administrador | API | True | True |
| Empresa recibe aviso persistido del resultado | API | True | True |
| Sitio web y redes persisten después de aprobar | Navegador + API | {'website': 'https://example.org', 'social': ['https://example.org/red']} | {'website': 'https://example.org', 'social': ['https://example.org/red']} |
| Logout de empresa aprobada revoca token | Navegador + API | 401 | 401 |
| Dashboard empresarial coincide con ofertas y postulaciones propias de QA | Navegador + API | {'active_offers': 2, 'closed_offers': 0, 'applications': 2} | {'active_offers': 2, 'closed_offers': 0, 'applications': 2} |
| Logout de empresa con actividad revoca token | Navegador + API | 401 | 401 |
| Registro Candidato: cuenta creada antes del selector | Navegador + API | 201 | 201 |
| Registro Candidato: rol persistido | Navegador + API | 200 | 200 |
| Verificación Candidato con enlace capturado localmente | API + correo a archivos | 200 | 200 |
| Verificación Candidato reutilizada es idempotente | API | 200 | 200 |
| Registro verificado permite login con destino candidato | Navegador + API | True | True |
| Perfil mantiene persistencia después de extraer repositorios | Navegador + API | Resumen ficticio QA después de la reorganización. | Resumen ficticio QA después de la reorganización. |
| Dashboard vuelve a consultar completitud del perfil editado | Navegador + API | 33 | 33 |
| Logout del candidato confirma revocación remota | Navegador + API | 401 | 401 |
| Recuperación solicitada desde Flutter | Navegador + API | 200 | 200 |
| Confirmación usa enlace capturado localmente y limpia su URL | Navegador | True | True |
| Contraseña anterior rechazada después de recuperación | API | 400 | 400 |
| Nueva contraseña permite acceso después de recuperación | API | 200 | 200 |
| Enlace de recuperación utilizado no se reutiliza | API | 400 | 400 |
| Logout después de recuperación revoca token nuevo | Navegador + API | 401 | 401 |
| Enlace de verificación inválido rechazado | API | 400 | 400 |
| Dashboard administrativo sin autenticación rechazado | API | 401 | 401 |
| Candidato no accede a revisión empresarial | API | 403 | 403 |
| Consulta empresarial de perfil continúa restringida sin selección autorizada | API | 403 | 403 |
| Sin errores JavaScript no controlados durante los recorridos | Consola del navegador | 0 | 0 |
| Logo opcional: archivo válido cargado desde Flutter y recuperado | Navegador + API | True | True |
| Archivo inválido rechazado sin perder el logo anterior | Navegador + API | True | True |
| Logo opcional eliminado desde Flutter | Navegador + API | 404 | 404 |
| Logout posterior a edición del logo revoca su token | Navegador + API | 401 | 401 |

## Capturas nuevas

Los correos y entidades mostrados son ficticios de QA. No contienen contraseñas visibles ni enlaces firmados. Las pantallas móviles se desplazan verticalmente; estas capturas muestran su viewport, no la página entera.

### Cuenta creada antes del rol

![Cuenta creada antes del rol](registro-empresa-rol-posterior.png)



### Registro y rol confirmados

![Registro y rol confirmados](registro-empresa-confirmado.png)



### Información de empresa

![Información de empresa](empresa-informacion-escritorio.png)



### Solicitud pendiente

![Solicitud pendiente](empresa-pendiente-escritorio.png)



### Dashboard administrativo

![Dashboard administrativo](administracion-escritorio.png)



### Datos de la solicitud

![Datos de la solicitud](solicitudes-escritorio.png)



### Motivo obligatorio

![Motivo obligatorio](rechazo-motivo-obligatorio.png)



### Empresa rechazada en móvil web

![Empresa rechazada en móvil web](empresa-rechazada-movil.png)



### Solicitud reenviada

![Solicitud reenviada](empresa-reenvio.png)



### Confirmación de aprobación

![Confirmación de aprobación](aprobacion-confirmacion.png)



### Administración en móvil web

![Administración en móvil web](administracion-movil.png)



### Dashboard de empresa sin actividad

![Dashboard de empresa sin actividad](empresa-dashboard-vacio.png)



### Dashboard empresarial con actividad

![Dashboard empresarial con actividad](empresa-dashboard-escritorio.png)



### Dashboard empresarial en móvil web

![Dashboard empresarial en móvil web](empresa-dashboard-movil.png)



### Cuenta creada antes del rol

![Cuenta creada antes del rol](registro-candidato-rol-posterior.png)



### Registro y rol confirmados

![Registro y rol confirmados](registro-candidato-confirmado.png)



### Regresión del candidato

![Regresión del candidato](candidato-regresion.png)



### Recuperación confirmada

![Recuperación confirmada](recuperacion-confirmada.png)



### Error de acceso

![Error de acceso](login-error-vigente.png)



### Correo duplicado

![Correo duplicado](registro-correo-duplicado.png)



### Logo y complementos de empresa aprobada

![Logo y complementos de empresa aprobada](empresa-logo.png)

Fotografía ficticia de QA cargada desde el selector de archivos; sitio web y redes ya persistidos.

### Archivo inválido

![Archivo inválido](empresa-logo-invalido.png)

La API rechaza un archivo sin contenido de imagen y conserva el logo válido anterior.

## Evidencia reutilizada y pendientes

Los informes [HU001](../hu001/README.md), [HU002](../hu002/README.md), [HU003](../hu003/README.md), [HU004](../hu004/README.md), [HU005](../hu005/README.md) y [HU008](../hu008/README.md) conservan casos/capturas históricos identificados. No se atribuyen sus conteos a nuevas ejecuciones. Registro antes del rol, estados empresariales, destinos de empresa/administrador y logout remoto ya se corrigieron; sus referencias antiguas se conservan como historial.

- SMTP real, recepción y apertura de los mensajes recibidos: #31/#32/#33 y #40/#41/#42.
- Dashboard candidato #47/#50: CV, búsqueda, mensajes, historial y detalle/postulación, pendientes de sus módulos. #48/#49 tienen resumen e integración disponibles para revisión.
- Dashboard empresa #51–#54: métricas e integración implementadas; accesos funcionales de gestión de ofertas/postulantes, mensajes y estadísticas pendientes de módulos posteriores. La API #52 está disponible para revisión.
- Administración #55/#58: gestión de administradores/permisos pendiente. #56/#57 y el recorrido de validación sí tienen evidencia.
- Perfil #60/#62: consulta por empresa con autorización dentro de selección pendiente; 403 conserva restricción sin acreditar el criterio positivo.
- Configuración #43–#46: disponible para revisión; no se bloquea por SMTP o historias empresariales. Preferencias no acreditan entrega push.
- HU009/HU010 #63–#70: flujo propio, decisiones, reenvío y avisos internos comprobados; revisión por otro integrante pendiente. Avisos internos no equivalen a correo ni a push.
- Validación nativa y revisión por otro integrante aún no realizadas. No se cerró ninguna tarea ni se fusionó PR.

[Guía breve de revisión](../../REVISION.md). [PR #146](https://github.com/Danilo2334/Work_net/pull/146).
