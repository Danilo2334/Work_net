# Evidencias del recorrido del candidato

Reconstrucción sobre `acb48b5`. Implementación/documentación: francisco3788.
QA: Danilo2334. Esta validación conserva las capturas vigentes de HU001.

Código validado: [a04eeec](https://github.com/Danilo2334/Work_net/commit/a04eeec8fd281ddca6f4a254f3b4c3441a79ad53).

| Parte | Qué funciona, cómo se probó, capturas y pendientes |
| --- | --- |
| Login y sesión — #34, #36, #38 | [HU002](../hu002/README.md) |
| Recuperación — #39, #41, #42 | [HU003](../hu003/README.md) |
| Dashboard — #47, #49, #50 | [HU005](../hu005/README.md) |

Resultados: análisis limpio, 40 pruebas Flutter, 70 del backend y
[19 comprobaciones en Chrome](resultados-qa.json) aprobadas.
Se revisaron escritorio 1440×1280 y móvil 390×844, con 16 capturas de estados clave.

El navegador consumió Django en una SQLite separada con cuentas verificadas y
filas identificadas como QA; los datos no están incrustados en Flutter.
Los correos se capturaron localmente. **SMTP real y recepción en un buzón no
están acreditados.** Contraseñas, tokens, mensajes y base de QA se mantienen
fuera de Git en `.dart_tool`.

Siguen pendientes estados/destinos empresariales y de administrador,
los módulos de acceso desde el dashboard, validación nativa y revisión final.
No se cierran historias ni tareas automáticamente. El PR #146 sigue en borrador.
