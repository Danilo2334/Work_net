# Normalización de evidencias backend y QA

Fecha de contexto: **18/10/2026 — America/Bogota**. Responsable de publicación:
**Danilo2334**. Ejecución automatizada por agente; revisión humana pendiente.

Para ordenar los comentarios se detectó que faltaban evidencias visuales de API
específicas y actuales. Se ejecutaron **60 comprobaciones HTTP reales** sobre
Django en 127.0.0.1:8005, con otra SQLite y correo a archivos, y se volvió a ejecutar
la suite backend existente: **87 pruebas, cero fallos**. No se cambió lógica del
producto ni se añadió una prueba que solo replique un cambio documental.

Código backend validado: `a40045545ff874b079392d55786992786093ee83`.
Los commits posteriores de esta normalización únicamente agregan documentación,
herramientas de evidencia e informes. La regresión Flutter de **67 pruebas** y
las capturas de las pantallas mantienen el alcance y la fecha de su entrega
publicada en `c104b02` / `2970dea`; no se presentan como una nueva ejecución aquí.

## Informes por tarea

| Tarea | API HTTP nueva | Pruebas automáticas pertinentes | Captura |
| --- | ---: | ---: | --- |
| #30 Registro y roles | 4 | 4 | [API de registro](api-tarea-30.png) |
| #31 Verificación local | 5 | 3 | [API de verificación](api-tarea-31.png) |
| #35 Autenticación | 4 | 6 | [API de login](api-tarea-35.png) |
| #40 Recuperación local | 8 | 7 | [API de recuperación](api-tarea-40.png) |
| #44 Configuración | 12 | 23 | [API de cuenta](api-tarea-44.png) |
| #45 Preferencias | 7 | 15 | [API de preferencias](api-tarea-45.png) |
| #48 Resumen candidato | 4 | 19 | [API de dashboard](api-tarea-48.png) |
| #60 Perfil y fotografía | 16 | 17 | [API de perfil](api-tarea-60.png) |

Las selecciones automáticas pueden solaparse; no se suman para obtener el total.
Los identificadores exactos están en [resumen-por-tarea.json](resumen-por-tarea.json).
Cada PNG es una captura en Chrome de un **informe automático**, generado del
resultado real de las peticiones y la suite. La tabla muestra método, ruta,
esperado/obtenido y un extracto sanitizado de respuesta. No se atribuye a Postman
ni a una comprobación humana. El HTML equivalente permite leer todo el contenido.

- [Resultados HTTP completos](api.json): peticiones, campos enviados (solo nombres),
  códigos esperados/obtenidos y respuestas sin credenciales.
- [Resultados de los 87 tests](suite.json): identificadores y resultados reales.
- HTML por tarea: `api-tarea-<número>.html`.

## Entorno y alcance

Se creó otra SQLite mediante `frontend/tool/qa_backend.py`. Las cuentas nuevas
utilizan direcciones ficticias `@worknet.test`; solo se eliminó la cuenta
desechable de QA. Los enlaces firmados se usaron en memoria y no se incluyen
en informes, imágenes, parámetros públicos ni logs de solicitudes.
La suite Django usa además su propia base temporal, separada de esa SQLite HTTP.
Los informes no incluyen contraseñas, tokens de sesión ni bytes de imágenes privadas.
La fotografía usa el archivo sintético QA ya publicado en HU008.

En correo se comprobó generación local, enlace válido/vencido, idempotencia o
reutilización y estados de la cuenta. **SMTP real y recepción en un buzón siguen
sin comprobarse.** Una respuesta HTTP 201/200 o una imagen del formulario no
acredita esa recepción. La persistencia se respalda en consultas API posteriores,
y los permisos en peticiones hechas con usuarios distintos y sin autenticación.

La consulta empresarial autorizada del perfil sigue pendiente de autorización
en selección: HTTP 403 es una denegación comprobada, no una prueba de acceso
autorizado. Para HU004, SMTP y estados empresariales de otras historias no
impiden su revisión/cierre cuando corresponda. No se cambia el estado ni los
criterios de cierre de ninguna tarea en esta normalización.

## Reproducir

Con requisitos instalados y el código frontend que contiene la herramienta QA,
desde la raíz de Work_net, terminal 1:

```powershell
python backend/docs/evidencias/normalizacion/servidor_qa.py .
```

Terminal 2, también desde la raíz:

```powershell
python backend/docs/evidencias/normalizacion/verificar_api.py . backend/docs/evidencias/normalizacion
python backend/docs/evidencias/normalizacion/verificar_suite.py . backend/docs/evidencias/normalizacion
python backend/docs/evidencias/normalizacion/crear_reportes.py
```

`servidor_qa.py` crea otra base cada vez. La configuración y las credenciales
aleatorias se conservan únicamente en `.dart_tool`, ignorado por Git. Nunca se
requiere configurar SMTP ni utilizar una cuenta real para reproducir este bloque.
Si falla una comprobación se detiene el script; revisar localmente antes de
publicar otro resultado. Las capturas se obtuvieron del HTML en una pestaña de
Chrome a 1120 px de ancho y altura suficiente para el documento completo.

Los comentarios de cada tarea incluyen solo explicación, casos pertinentes,
imágenes con leyenda, referencias y pendientes específicos. Las versiones
anteriores se conservan identificadas como históricas; las fechas originales,
Sprints, criterios y responsables no se modifican.
