# HU008 — API privada del perfil del candidato

Responsable backend: Danilo2334, tarea #60. Usa el perfil existente sin borrar
sus listas JSON anteriores. Los registros nuevos son objetos con identificador
estable y campos estructurados, reutilizables por un futuro generador de CV.
La generación de CV no forma parte de esta API.

Las rutas propias requieren `Authorization: Token …`, candidato verificado, sin
privilegios staff/superusuario. Consultan únicamente al propietario del token.
No existe una ruta pública ni un parámetro para seleccionar a otro candidato.

| Método | Ruta bajo `/api/profile/candidate/` | Entrada / salida |
| --- | --- | --- |
| GET | raíz | Perfil propio y completitud; vacío no crea filas |
| POST | raíz | `{professional_summary: string}`; crea con HTTP 201; existente HTTP 409 |
| PATCH | raíz | `{professional_summary: string}`; actualiza o HTTP 404 si aún no existe |
| DELETE | raíz | Borra perfil, registros y fotografía; conserva la cuenta |
| GET / POST | `education/`, `experience/`, `skills/`, `languages/` | Lista / creación de registro propio |
| GET / PATCH / DELETE | `<sección>/<id>/` | Consulta / edición parcial / eliminación por identificador |
| PUT | `photo/` | Multipart con un único archivo `photo` |
| GET | `photo/` | JPEG privado, con token; HTTP 404 si no existe |
| DELETE | `photo/` | Elimina solamente la fotografía opcional |

Los cambios de perfil, registros y foto devuelven `profile` y
`profile_completion`. El perfil contiene `exists`, `professional_summary`,
`has_photo` y las cuatro listas. La consulta de sección devuelve `records`,
y la de registro individual, `record`. Los errores de validación devuelven
HTTP 400 con `message` y `errors`. Acceso anónimo HTTP 401; otros roles HTTP 403;
identificador ajeno o inexistente HTTP 404. Los campos desconocidos se rechazan.

## Datos estructurados

- `education`: `qualification` obligatorio, `institution` opcional.
- `experience`: `position` obligatorio, `company` opcional.
- Ambos aceptan `start_date`, `end_date` (`YYYY-MM-DD` o null) y `description`.
  La fecha final debe ser igual o posterior a la inicial, también en PATCH.
- `skills`: `name` obligatorio, `level` opcional: vacío, `basico`, `intermedio`, `avanzado`.
- `languages`: `name` obligatorio, `level` opcional: vacío, A1/A2/B1/B2/C1/C2 o `nativo`.
- Identificadores generados por el servidor; no se aceptan en escrituras.
- Hasta 100 registros por sección; títulos/instituciones/puestos/empresas hasta
  200 caracteres; nombres de habilidad/idioma hasta 100; descripción de registro
  hasta 3000 y descripción profesional hasta 5000.

Las listas históricas admitían cadenas u objetos con `title`. Se adaptan al leer
con nombres de campo canónicos e identificadores deterministas. GET no escribe
ni borra información. Al modificar una lista se conservan claves históricas no
reconocidas; los PATCH cambian únicamente campos enviados. Los registros nuevos
usan el contrato anterior. Las pruebas cubren esta compatibilidad y la persistencia.

La completitud reutiliza el cálculo de HU005: datos básicos, descripción,
educación, experiencia, habilidades e idiomas, con igual peso. La fotografía
es opcional y no reduce el porcentaje cuando falta. Borrar registros o el perfil
actualiza la completitud en la siguiente consulta de dashboard.

## Fotografía privada

Se aceptan JPEG/PNG estáticos hasta **2 MiB**, lado máximo **4096 px** y área
máxima **16 MP**. Se comprueban extensión, MIME, formato real y decodificación;
se rechazan archivos truncados, formatos incompatibles y cargas múltiples.
La imagen se orienta, reduce como máximo a 1024×1024 y recodifica como JPEG
solo con píxeles, sin EXIF, nombre original ni metadatos del archivo recibido.
Una carga inválida conserva la foto anterior.

Los bytes se almacenan en la fila privada del perfil, sin `MEDIA_URL` ni ruta
de archivo pública. GET requiere el mismo permiso que el perfil y devuelve
`Cache-Control: private, no-store`, `Vary: Authorization` y `nosniff`.
No se coloca el token en URL ni en una etiqueta de imagen sin autenticación.
Las copias de seguridad de la base contienen también estas imágenes; para
volúmenes mayores se podrá migrar a almacenamiento privado manteniendo el contrato.

Referencias de implementación: [parsers multipart de DRF](https://www.django-rest-framework.org/api-guide/parsers/)
y [validación y límites de imágenes de Pillow](https://pillow.readthedocs.io/en/stable/reference/Image.html).

## Consulta empresarial dentro de selección

La regla de HU008 se concreta con la restricción de HU020: solo la empresa dueña
de una oferta puede consultar el perfil de quienes se postularon a ella. Requiere
cuenta empresarial verificada y aprobada; staff y administradores no usan esta ruta.
No se admite elegir libremente un candidato ni una empresa mediante parámetros.

| Método | Ruta bajo `/api/` | Salida |
| --- | --- | --- |
| GET | `company/applications/<application_id>/profile/` | `application` con ID y oferta, `candidate` con ID y nombre, `profile` y completitud |
| GET | `company/applications/<application_id>/profile/photo/` | JPEG privado; 404 si no hay fotografía |

El ID procede de una postulación real, disponible en el resumen empresarial.
Otra empresa aprobada recibe el mismo 404 que ante un ID inexistente. Sin sesión
se devuelve 401; otro rol o empresa sin aprobación recibe 403. Estas rutas solo
admiten lectura. Las rutas de edición anteriores siguen reservadas al candidato.
La respuesta no incluye contraseña, token, correo de la cuenta ni preferencias.
Las claves históricas no reconocidas se conservan en la edición propia, pero no
se incluyen en la consulta empresarial.
Perfil y foto usan `Cache-Control: private, no-store` y `Vary: Authorization`.

Eliminar la postulación retira el acceso; la autorización se comprueba en cada
petición. Una oferta cerrada o archivada conserva su historial de selección.
Consultar un perfil vacío no crea filas. La consulta empresarial no implementa
todavía la interfaz completa de gestión de postulantes de HU020.

Las pruebas de `candidate_dashboard.test_profile` y
`candidate_dashboard.test_selection` cubren CRUD propio, compatibilidad, imágenes,
permisos de selección, aislamiento, lectura sin escrituras y revocación por
eliminación de la postulación. La fase 12 de la colección Postman repite los
recorridos HTTP disponibles; la guía distingue sus ejecuciones de apoyo y Desktop.
