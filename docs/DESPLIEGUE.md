# WorkNet · Plan de despliegue

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

## Secuencia de publicación

1. Confirmar cuenta/workspace, duración de la presentación y presupuesto. Elegir recursos/región y preparar un Blueprint revisable sin aplicar servicios todavía.
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

Para una publicación duradera, confirmar los planes vigentes de web y PostgreSQL antes de activarlos. No se fija importe sin consultar catálogo y panel de la cuenta. Esta limpieza no crea recursos, activa facturación ni transfiere credenciales.

## Intervención manual prevista

Confirmar cuenta/workspace y presupuesto; autorizar la conexión GitHub si el alojamiento la solicita; completar en privado las credenciales de correo y Gemini. El administrador configura su propio TOTP. Código, configuración y pruebas pueden prepararse antes de esa intervención, manteniendo los secretos fuera del repositorio.

## Referencias oficiales

- [Django en Render](https://render.com/docs/deploy-django): PostgreSQL, servidor y estáticos.
- [Recursos gratuitos Render](https://render.com/docs/free): suspensión, almacenamiento, SMTP y caducidad.
- [Publicación web Flutter](https://docs.flutter.dev/deployment/web): build/web y artefacto release.

La aceptación actual usa Windows/SQLite. No se atribuyen todavía validación productiva ni pruebas PostgreSQL.
