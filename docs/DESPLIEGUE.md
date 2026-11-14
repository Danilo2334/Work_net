# WorkNet · Plan de despliegue

**APK vigente: [0.1.2 release](https://worknet.3.136.118.169.sslip.io/descargar/)**. Actualización y sesión probadas en emulador Android 12, incluida aceptación por el instalador estándar. Pendiente confirmar en los dos teléfonos que rechazaban 0.1.1; causa física no reproducida. Véase la sección vigente de REVISION.md.

**Actualización 13/11/2026:** [descargar APK Android 0.1.1](https://worknet.3.136.118.169.sslip.io/descargar/). Página independiente publicada en el mismo servidor, con descarga completa y SHA-256 verificados. El bloqueo anterior de Gradle quedó resuelto; es una compilación de presentación, no de Google Play. [Revisión vigente y evidencias](../frontend/docs/REVISION.md).

## Despliegue vigente: AWS con créditos — 10/11/2026

Se trabaja en una copia aislada desde main `197f536`, conservando los entornos anteriores. Con autorización expresa del usuario se creó Lightsail Linux de **2 GB, 2 vCPU y 60 GB por US$12/mes contra créditos**, Ubuntu 24.04, en `us-east-2`. El proyecto `worknet` conserva el plan **FREE**; no se activó Paid. PostgreSQL, Redis, Django y Flutter/Caddy están preparados para esa misma instancia, sin contratar servicios gestionados adicionales. El saldo exacto restante debe consultarse en AWS Settings.

**[WorkNet está publicada con HTTPS](https://worknet.3.136.118.169.sslip.io/login)** y certificado público de Let’s Encrypt verificado sin excepciones. Pasaron seis controles HTTPS, 61 de API, Gemini real, las tres plantillas PDF, TOTP, navegador de escritorio/móvil web y respaldo/restauración en otra base. PostgreSQL/Redis conservaron los datos al reiniciarse. [Resultados y capturas](../frontend/docs/REVISION.md) · [registro AWS](aws-despliegue-20261110.json) · [operación y recuperación](../deploy/aws/README.md).

SSH quedó corregido: la regla permitía una IP distinta del origen TCP real, confirmado en una sesión autenticada. El 2222 queda limitado a ese `/32`, conservando intacto el 22 y el cliente del navegador. Las huellas del host se verificaron con la API de AWS. [#245](https://github.com/Danilo2334/Work_net/pull/245) quedó fusionado en `develop`; [#246](https://github.com/Danilo2334/Work_net/pull/246) incorpora el backend revisado para la entrega conjunta. Gemini permanece exclusivamente en el backend; HU027 sigue pendiente. El servidor consume créditos incluso apagado hasta su retirada explícita.

El usuario confirmó recepción del correo real y apertura de «Nueva contraseña» en HTTPS. **Pendientes delimitados:** captura nueva de Postman Desktop y APK cloud. Gradle falló localmente con `Unable to establish loopback connection`; la APK anterior se conserva y la web pública no depende de ese build ni del USB. Los 308 Django SQLite, 306+2 PostgreSQL y 237 Flutter del ensayo local mantienen su fecha y procedencia, sin presentarse como nuevas ejecuciones en AWS.

La propuesta Render siguiente se conserva como antecedente del corte anterior. Su presupuesto no es la elección vigente.

## Antecedente: propuesta Render

**09/11/2026: propuesta preparada; aplicación completa todavía sin desplegar.** HU001–HU026 y HU028 están entregadas. HU027 se mantiene para v2 y no es una dependencia del despliegue.

## Opción recomendada

Flutter como sitio estático HTTPS y Django como servicio web en Render, con PostgreSQL gestionado en la misma región. Elegir un servicio compatible con el correo configurado y una base de datos sin caducidad de demostración para conservar la entrega.

| Recurso | Contenido | Preparación |
| --- | --- | --- |
| Sitio estático | Compilación release Flutter | API_BASE_URL al origen HTTPS real de Django, terminando en /api/. Resolver rutas de navegación hacia index.html. |
| Servicio Python | Django y endpoints privados | Gunicorn en 0.0.0.0:$PORT, configuración productiva y servicio de estáticos. |
| PostgreSQL | Usuarios, ofertas, postulaciones, mensajes, TOTP y documentos | Migraciones probadas, conexión privada, copia de seguridad y restauración ensayada. |
| Correo | Verificación y recuperación | Configuración privada y entrega real con enlaces del sitio publicado. |
| Gemini | Propuestas de CV | Clave/modelo solo backend; comprobar cuota, consentimiento y errores en el entorno publicado. |

**Almacenamiento confirmado:** UploadedCurriculum.document, Application.cv_document, CandidateProfile.photo_data y CompanyProfile.logo_data son campos binarios de la base de datos. No hace falta un disco público para esos archivos; las copias PostgreSQL deben incluirlos. No exponerlos como archivos estáticos ni enlaces públicos.

La primera publicación debe utilizar datos ficticios y probarse de extremo a extremo antes de abrir registro a usuarios reales.

## Ajustes previos encontrados

| Área actual | Trabajo pendiente de despliegue |
| --- | --- |
| backend/config/settings.py | Separar producción: DEBUG=False, secreto nuevo privado, ALLOWED_HOSTS explícitos, HTTPS/proxy confiable, cookies seguras y CORS/CSRF concretos. Ahora contiene configuración de desarrollo. |
| Base de datos | Configurar DATABASE_URL y adaptador PostgreSQL; conservar SQLite local. Ejecutar regresión y migraciones contra PostgreSQL. |
| backend/requirements.txt | Añadir y fijar servidor WSGI, adaptador PostgreSQL y servicio de estáticos; no incluye Gunicorn, psycopg ni WhiteNoise. |
| Estáticos y salud | Preparar STATIC_ROOT/collectstatic y un health check sin datos privados. |
| Límite de IA | La caché local no coordina procesos y se pierde al reiniciar. Configurar caché compartida para mantener el límite entre workers/instancias. |
| Correo | Confirmar conectividad del plan o implementar transporte por API HTTPS si bloquea SMTP. El correo actual usa Gmail SMTP en 587. |
| Flutter | Build con API_BASE_URL real; probar recarga de rutas, descargas PDF/CSV y cabeceras de exportación con CORS. |
| Automatización | Versionar configuración de despliegue después de elegir recursos y validar comandos. Este corte no incluye render.yaml ni servicio productivo. |

DJANGO_SECRET_KEY, DJANGO_ALLOWED_HOSTS, DATABASE_URL y REDIS_URL pueden adoptarse en esa configuración; no se presentan como variables ya soportadas por el settings actual. Las variables de correo y GEMINI_API_KEY/GEMINI_MODEL sí existen.

## Propuesta concreta para esta entrega

La consulta de lectura del 09/11/2026 confirmó acceso al **My Workspace de francisco3788**, ya autorizado. No hay servicio ni PostgreSQL de WorkNet; los otros servicios encontrados pertenecen a proyectos distintos y se conservan. No es necesario volver a confirmar ese workspace para continuar.

Recomiendo mantener todo el alojamiento en Render: Flutter estático, API Django, PostgreSQL y caché compartida en la misma región de la API. Los dominios HTTPS iniciales de Render evitan comprar un dominio para presentar. La página informativa GitHub Pages actual no sustituye el despliegue de la aplicación.

| Recurso propuesto | Plan de referencia | Cómputo orientativo al mes |
|---|---|---|
| Flutter estático | Static Site | Sin coste de cómputo, dentro de las cuotas. |
| API Django | `0.5c-512mb` (antes Starter) | US$7. |
| PostgreSQL | `0.1c-256mb` | US$6 más almacenamiento. |
| Caché compartida persistente | Key Value `256mb` | US$10. |

**Referencia de presupuesto: US$23/mes de cómputo, más almacenamiento, impuestos y excesos de uso.** No es un cargo activado ni una cotización definitiva. Confirmar el total del panel y los límites antes de crear recursos. El workspace Hobby no requiere cambiarse a Pro para estos recursos; los servicios se facturan aparte. Para una demostración temporal sin presupuesto habría que elegir otra combinación y resolver primero el correo por HTTPS y la caducidad de la base; no se ofrece el despliegue gratuito actual como equivalente funcional del Gmail SMTP existente.

La siguiente fase implementaría configuración productiva, adaptador PostgreSQL/WSGI/estáticos, caché y Blueprint; luego ensayaría PostgreSQL, migraciones, correo real, Gemini, TOTP, PDF/CSV, persistencia y copia/restauración con datos ficticios. La aprobación de recursos y coste sería el último paso antes de activarlos, con la configuración ya preparada y revisable. No se crean funcionalidades de una versión futura ni se incorpora HU027.

Precios y planes contrastados con [tarifas oficiales](https://render.com/pricing), [IDs de planes](https://render.com/docs/compute-plans) y [límites gratuitos](https://render.com/docs/free). Los secretos se reutilizan o configuran solo en el panel privado del backend; nunca se solicitan por el chat.

## Secuencia de publicación

1. Conservar el workspace ya verificado y definir duración de la presentación y presupuesto. Elegir recursos/región y preparar un Blueprint revisable sin aplicar servicios todavía.
2. Implementar los ajustes anteriores en una rama de despliegue. Validar configuración y comportamiento en PostgreSQL; no reutilizar bases QA históricas.
3. Completar secretos en el panel privado. No copiarlos a README, Issues, Flutter ni al chat. Revisar recursos y costes antes de activarlos.
4. Publicar la configuración y crear los recursos aprobados. Ejecutar migraciones una vez mediante el mecanismo elegido; aprovisionar el principal en un procedimiento privado de una sola ejecución, nunca mediante contraseña incluida en el build.
5. Obtener el origen HTTPS real de Django y compilar desde frontend:

```bash
flutter build web --release --no-web-resources-cdn --dart-define=API_BASE_URL=https://DOMINIO-REAL-DEL-BACKEND/api/
```

DOMINIO-REAL-DEL-BACKEND es un marcador, no un endpoint existente. Publicar frontend/build/web. No incorporar los artefactos de compilación al historial de código fuente.

6. Ajustar orígenes permitidos y PASSWORD_RESET_FRONTEND_URL al dominio real del frontend. Probar correo, autenticación, TOTP y revocación de sesiones.
7. Probar candidato → IA/CV → búsqueda → postulación → empresa → estado/mensajes → avisos → exportación y administración. Reiniciar y confirmar persistencia. Contrastar PDF y CSV descargados.
8. Ensayar copia/restauración y registrar URL, SHA, resultados y límites en la guía. Conservar una versión anterior desplegable; revertir código no restaura la base de datos y requiere migraciones compatibles.

## Coste y límites

La documentación Render consultada el 09/11/2026 indica que el web gratuito se suspende tras 15 minutos de inactividad, tiene sistema de archivos efímero y bloquea salida SMTP 25/465/587. PostgreSQL gratuito caduca a los 30 días y no incluye copias de seguridad. Son límites relevantes para exponer con estabilidad y conservar datos.

Para una publicación duradera, confirmar los planes vigentes de web y PostgreSQL antes de activarlos. La referencia de cómputo se detalla arriba; el total requiere comprobar almacenamiento, cuotas y panel de la cuenta. Esta limpieza no crea recursos, activa facturación ni transfiere credenciales.

## Intervención manual prevista

Definir presupuesto; conservar el workspace ya verificado y autorizar la conexión GitHub si el alojamiento la solicita; completar en privado las credenciales de correo y Gemini. El administrador configura su propio TOTP. Código, configuración y pruebas pueden prepararse antes de esa intervención, manteniendo los secretos fuera del repositorio.

## Referencias oficiales

- [Django en Render](https://render.com/docs/deploy-django): PostgreSQL, servidor y estáticos.
- [Recursos gratuitos Render](https://render.com/docs/free): suspensión, almacenamiento, SMTP y caducidad.
- [Publicación web Flutter](https://docs.flutter.dev/deployment/web): build/web y artefacto release.

La aceptación actual usa Windows/SQLite. No se atribuyen todavía validación productiva ni pruebas PostgreSQL.
