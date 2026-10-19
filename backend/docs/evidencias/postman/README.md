# Pruebas del backend en Postman

19/10/2026. Seguimiento de QA: **Danilo2334**.

Se probaron los servicios de WorkNet desde Postman Desktop, con Django en funcionamiento y datos ficticios en bases separadas. Las dos ejecuciones terminaron sin fallos.

| Ejecución | Peticiones | Comprobaciones aprobadas | Fallos |
|---|---:|---:|---:|
| Primera | 212 | 631 | 0 |
| Segunda, desde otra base nueva | 212 | 631 | 0 |

## Qué se comprobó

| Tarea | Pruebas principales |
|---|---|
| #30 · Registro | Cuenta nueva, elección del rol, validaciones y correo repetido |
| #31 · Verificación | Enlace válido, ausente, inválido y apertura repetida |
| #35 · Acceso y salida | Credenciales, roles, cuenta verificada y revocación de sesión |
| #40 · Recuperación | Solicitud, cambio de contraseña y rechazo del enlace usado |
| #44 · Cuenta | Nombre conservado, cambio de contraseña y eliminación de cuenta desechable |
| #45 · Preferencias | Guardado y consulta posterior de notificaciones |
| #48 · Candidato | Resumen propio, completitud y permisos |
| #52 · Empresa | Resumen propio y acceso de empresa aprobada |
| #56 · Administrador | Conteos, avisos y acceso exclusivo |
| #60 · Perfil | Guardado, edición, eliminación, fotografías y separación entre usuarios |
| #64 · Información empresarial | Datos obligatorios, NIT único, guardado y permisos |
| #68 · Validación empresarial | Aprobación, rechazo con motivo, corrección y reenvío |

## Capturas y repetición

Las **22 capturas de Postman** muestran las peticiones, respuestas y comprobaciones de los casos principales. Se conservan también las capturas originales de entregas anteriores.

- [Ver las capturas con su explicación](capturas/README.md).
- [Importar la colección y repetir las pruebas desde cero](../../../postman/README.md).

En estas dos ejecuciones los enlaces se tomaron del correo guardado localmente. El registro y la recuperación con correo recibido se comprobaron antes y conservan su evidencia separada.

## Pendientes

- Revisión por otro integrante y pruebas en Android/iOS.
- Consulta del perfil por una empresa autorizada durante la selección.
- Módulos futuros de los dashboards y gestión de administradores.

El PR #146 continúa en borrador. Los criterios de las tareas y sus revisiones pendientes se conservan.
