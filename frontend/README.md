# WorkNet · Frontend Flutter

Primer bloque de reconstrucción: formulario HU001, elección de rol público,
petición real de registro y confirmación para revisar el correo.

## Alcance

- Nombre completo, correo, contraseña y confirmación con validaciones visibles.
- Primero se completan los datos del formulario y luego se elige Candidato o Empresa.
- Se envían juntos en `POST /api/register/`, como requiere la API existente.
- El correo duplicado y las validaciones de Django se muestran al usuario.
- El envío en curso bloquea acciones que puedan repetir la petición.
- El éxito solo se anuncia al recibir HTTP 201 y los datos esperados.
- La contraseña se conserva únicamente en memoria durante el formulario y se limpia al terminar.
- Diseño adaptable a móvil y escritorio con la paleta verde de los mockups.

Este bloque no declara terminada HU001 ni todo el frontend. Faltan el login,
la navegación al dashboard y el formulario de información/validación de empresa.
El correo de verificación lo envía Django; al abrir su enlace se utiliza el
endpoint de verificación que ya existe. Esta entrega no agrega reenvío de correo.

## Ejecutar en Chrome

En otra terminal, desde `backend`, activar el entorno virtual y ejecutar:

```powershell
python manage.py runserver
```

Si se van a crear cuentas reales, el correo SMTP debe estar configurado en el
archivo local `backend/.env`, según el README del repositorio. Esta entrega no
modifica esa configuración.

Desde `frontend`:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --web-port 55000 --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/
```

Se incluye la plataforma Android para continuar posteriormente. La prueba
inicial indicada arriba es web, contra el servidor local de Django. Los
permisos de Internet quedan habilitados; el HTTP sin cifrar se permite solo en
los manifiestos de desarrollo de Android. Para publicar se debe usar una API HTTPS.

## Comprobación funcional breve

1. Continuar con campos vacíos: errores visibles y ninguna petición de registro.
2. Contraseñas diferentes: no permite pasar a la selección de rol.
3. Datos válidos: solo aparecen Candidato y Empresa. Volver conserva los datos.
4. Correo ya registrado: Django lo rechaza y el error aparece junto al correo.
5. Crear un candidato y una empresa con correos nuevos: respuesta 201, rol
   correcto y pantalla de revisar correo. Abrir el enlace recibido verifica
   la dirección en Django; el acceso posterior pertenece al siguiente bloque.

## Verificación de esta entrega

La reconstrucción se validó en Windows con el SDK instalado en el equipo del
proyecto. `flutter analyze` terminó sin incidencias y las 21 pruebas Flutter
aprobaron. Cubren contrato HTTP, validaciones, errores, duplicación de envíos,
selección de ambos roles y tamaños de pantalla de móvil y escritorio.

La corrección de correo duplicado del backend está separada en el commit
`763fceb`, de Danilo2334, en `feature/backend-sprint-2`. Las 70 pruebas de
`accounts` y `candidate_dashboard` aprobaron, incluida la regresión del mensaje
en español con correos repetidos, mayúsculas y espacios.

La comprobación visual conectó Flutter en `http://localhost:55000` con Django
en `http://127.0.0.1:8001/api/`, porque el puerto 8000 estaba ocupado. Se
verificaron el registro HTTP 201, el duplicado HTTP 400 y la presentación de
escritorio. Se usó una copia aislada de SQLite y captura local del correo;
esto no comprueba entrega real a Gmail ni verificación desde el correo recibido.

Las [capturas y límites de la validación](docs/evidencias/hu001/README.md)
corresponden a la reconstrucción y complementan las tareas #29, #32 y #33.
SMTP real, continuación al dashboard e información/validación empresarial
siguen pendientes. **HU001 todavía no está completa.**
