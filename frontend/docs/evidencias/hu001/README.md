# Reconstrucción de HU001 — evidencia local

**Estado: validación parcial del nuevo frontend, 17 de octubre de 2026.**

Esta evidencia corresponde a la reconstrucción Flutter, relacionada con #29,
#32 y #33. Las tareas cerradas de la entrega anterior no se consideran una
aprobación completa de este bloque nuevo.

## Comprobado

- Campos obligatorios y contraseñas coincidentes impiden avanzar con datos inválidos.
- Selección de Candidato y Empresa antes de enviar los datos.
- Registro contra Django con HTTP 201 y confirmación visual de correo y rol.
- Correo repetido con HTTP 400 y «Este correo ya está registrado.» junto al campo.
- Revisión visual de escritorio sin recortes visibles.

## Pruebas automatizadas

| Área | Comando | Resultado |
| --- | --- | --- |
| Flutter | `flutter analyze` | Sin incidencias |
| Flutter | `flutter test` | 21 pruebas aprobadas |
| Backend | `python manage.py test accounts candidate_dashboard --noinput` | 70 pruebas aprobadas |

El backend se verificó en `feature/backend-sprint-2`, commit `763fceb`,
con la corrección de correo duplicado de Danilo2334. El avance Flutter
y estas evidencias se publican por separado en `frontend`, con Francisco Molina.

## Alcance de la integración local

Flutter se ejecutó en el puerto 55000 y Django en el 8001, con
`API_BASE_URL=http://127.0.0.1:8001/api/`. La comprobación visual utilizó una
copia aislada de SQLite y el backend de correo a archivos de Django, configurados
solo para el proceso de prueba. No se modificó la configuración SMTP del proyecto.

Las capturas muestran el correo solicitado para la prueba. La cuenta se creó
en la copia de prueba y no ocupa ese correo en la base habitual. La pantalla
«Revisa tu correo» demuestra la respuesta HTTP 201; **no demuestra entrega
real en Gmail**.

## Capturas

### Formulario

![Formulario de registro](formulario.png)

### Registro exitoso en la prueba local

![Registro HTTP 201 con correo y rol](registro-exitoso.png)

### Correo repetido en español

![Correo duplicado HTTP 400 en español](correo-duplicado.png)

## Pendiente

- Entrega real mediante SMTP y verificación desde el correo recibido.
- Continuación al dashboard del candidato.
- Información empresarial y solicitud de validación.

**Esta evidencia no declara HU001 completa.**
