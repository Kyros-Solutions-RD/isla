# Novedades

Versión en español de [CHANGELOG.md](CHANGELOG.md). Cada sección `## x.y.z` se publica en https://isla.kyrosrd.com/novedades/.

## 1.1.7 — 2026-11-05

- Un agente que termina y se cierra (una ejecución puntual, una terminal cerrada) ya no desaparece sin más: se queda diez minutos en la pestaña IA como **Terminado**, y la isla avisa de que acabó.
- Las apps de IA abiertas aparecen como fichas con su nombre, y cuando LM Studio u Ollama están en marcha sin ningún modelo cargado, un botón los abre.
- Una pestaña con mucho contenido ya no puede empujar la cabecera del notch hacia arriba, bajo la cámara.

## 1.1.6 — 2026-11-05

- El menú de la barra de menús muestra los agentes trabajando o esperando, con su estado; haz clic en uno para traer su app al frente. También abre la pestaña IA.
- ⌘0 cambia a la décima pestaña, después de ⌘1…⌘9.
- VoiceOver lee la cabecera del notch por su nombre (Nook, IA, Bandeja… Mantener abierto, Ajustes) en lugar de describir los íconos, y lee cada agente con su herramienta, modelo, estado, paso actual y carpeta.

## 1.1.5 — 2026-11-05

- La ventana de Ajustes se llama como el panel en el que estás, como los Ajustes del Sistema.
- En la pestaña IA, un título de sesión largo conserva su espacio: la etiqueta se acorta al modelo, porque el ícono ya muestra la herramienta.
- Los estados vacíos de todas las pestañas salen del notch línea por línea, como las tarjetas del Nook.
- El recorrido de bienvenida presenta los Agentes de IA.

## 1.1.4 — 2026-11-05

- Más ahorro de batería, medido pestaña por pestaña: la pestaña Enfoque con un temporizador en marcha pasó de un 39 % de un núcleo a menos de un 2 %, y un temporizador alrededor del notch cerrado de un 10 % a menos de un 1,5 %.
- El cronómetro solo se redibuja mientras corre, y los anillos de los temporizadores ya no animan cada segundo un cambio demasiado pequeño para verse.
- Las descargas de tamaño desconocido giran su anillo con Core Animation en lugar de redibujar el notch.

## 1.1.3 — 2026-11-05

- Mucho más ligera con la batería: las animaciones del notch (los puntos de los agentes, el halo y el ecualizador de la música) ahora usan Core Animation. Con un agente trabajando o música sonando y el notch cerrado, Isla pasó de un 12 % de un núcleo a un 0,2 %, y la pestaña IA abierta de un 45 % a menos de un 2 %.
- Un agente que espera tu permiso, una respuesta o un diálogo ahora aparece como **Te necesita**, con el motivo y lo que pidió, y la isla te avisa al instante. También cuenta cuando Codex pide aprobación.
- La pestaña IA muestra el tamaño del contexto de cada sesión al pasar el puntero sobre su modelo.
- Sonido opcional cuando un agente termina o te necesita, en Ajustes › Agentes de IA.

## 1.1.2 — 2026-11-05

- Nuevo widget **Agentes de IA** para el Nook: los agentes trabajando, su proyecto, su estado y el tiempo, de un vistazo junto a tu música y el clima. Haz clic para abrir la pestaña IA. Añádelo en Ajustes › Nook y widgets.
- La barra de progreso de Tareas ahora va a juego con el resto del notch y se queda vacía hasta que terminas algo.

## 1.1.1 — 2026-11-05

- La pestaña IA muestra el modelo que usa cada sesión, cuándo empezó y cuánto tiempo lleva trabajando o esperando.
- Las sesiones de Codex ahora muestran si hay un turno en marcha, qué está haciendo (el comando que ejecuta o el archivo que edita) y cuánto lleva usado de su límite de uso de 5 horas.
- Los modelos locales muestran los servidores en marcha debajo del título, y el tamaño de contexto pasó a la ayuda emergente, así que nada se corta.
- Los nombres de carpeta se leen bien: cuando falta espacio, la pestaña IA muestra solo el proyecto.
- Las listas del notch (IA, Calendario, Tareas, Enfoque y Notas) se desvanecen en los bordes en lugar de cortarse.

## 1.1.0 — 2026-11-05

- Nueva pestaña **IA**: los agentes de programación que corren en tu Mac, en Terminal o en su propia app, con la carpeta en la que trabaja cada uno, desde cuándo está en marcha y si está trabajando, esperando o te necesita. También muestra qué hace cada agente en este momento y su actividad del último minuto.
- Los editores con agente, como Antigravity y Cursor, aparecen con su proyecto abierto, y las apps de IA que tienes abiertas quedan a un clic.
- Modelos locales: mira qué modelos tienen Ollama y LM Studio en memoria, cuánta memoria usan y cuándo se descargan.
- Mientras un agente trabaja, su ícono y su proyecto aparecen alrededor del notch cerrado. Cuando termina o se para a preguntarte algo, la isla te avisa, y un punto en la pestaña IA también lo indica.
- Ajustes › Agentes de IA activa o desactiva la pestaña, la actividad en el notch y los avisos, y te deja añadir cualquier otro agente por el nombre de su comando. Sin permisos nuevos: Isla solo mira tus propios procesos y nada sale de tu Mac.

## 1.0.5 — 2026-11-05

- La sección Actualizaciones de Ajustes › Acerca de ya está traducida por completo.
- Ajustes › Privacidad explica qué hacer cuando Accesibilidad aparece activada en Ajustes del Sistema pero no se aplica a Isla.
- Comprobado en un Mac real: los permisos que concedes a Isla se conservan al actualizar.

## 1.0.4 — 2026-11-05

- El Nook ahora se abre como la Dynamic Island: con un rebote suave, y las tarjetas salen del notch una tras otra.
- Las pestañas entran desde el lado que elegiste, y sus íconos se iluminan bajo el puntero.
- Las actividades en vivo salen de la cámara hacia cada lado.
- Una canción nueva cambia la portada con un desenfoque suave, y el notch se infla cuando le arrastras un archivo.
- Los permisos que concedas a la 1.0.3 o posterior se conservan en cada actualización.

## 1.0.3 — 2026-11-05

- Isla ya conserva el permiso de Accesibilidad y los demás al actualizarse. Cada versión se firma con una identidad estable en lugar de una distinta cada vez. Como la identidad cambia una sola vez, macOS vuelve a pedir los permisos de Isla después de instalar la 1.0.3: permite de nuevo Calendario, Recordatorios, Ubicación y los demás desde el Nook o Ajustes › Privacidad, y apaga y enciende Accesibilidad para Isla en Ajustes del Sistema.
- El recorrido de bienvenida y Ajustes › Privacidad muestran cada permiso en cuanto lo concedes, sin volver a abrirlos.
- La tarjeta del clima muestra las próximas horas debajo de la temperatura actual.

## 1.0.2 — 2026-11-05

- Corrige que Isla no abriera: las versiones 1.0.0 y 1.0.1 se cerraban justo al iniciar en todos los Mac. Si instalaste una de ellas, descarga Isla de nuevo desde isla.kyrosrd.com.
- La ventana de bienvenida, los Ajustes, AirDrop y Vista rápida ahora aparecen al frente y responden al teclado.
- Cerrar la bienvenida antes de tiempo ya no deja apagados el calendario, el clima, el Bluetooth ni la búsqueda de actualizaciones hasta el siguiente inicio.
- Ahora cada versión se abre y se comprueba antes de publicarse.

## 1.0.1 — 2026-11-05

![El instalador nuevo: Isla flota sobre el horizonte y el camino punteado del sol lleva a Aplicaciones](website/assets/app/installer.jpg)

- Un instalador ilustrado nuevo: arrastra Isla sobre el atardecer caribeño para instalarla, con ayuda para la primera apertura en español e inglés.
- La app ya muestra su ícono nuevo. La versión 1.0.0 salió con el anterior.
- Pasos más claros para abrirla por primera vez en macOS 26: Ajustes del Sistema › Privacidad y seguridad › Abrir igualmente.

## 1.0.0 — 2026-11-05

Primera versión pública.

![El Nook en Liquid Glass con Reproduciendo, A continuación y Clima](website/assets/app/glass-home.jpg)

- Panel del notch en cada pantalla, en Liquid Glass o negro clásico, con tres tamaños y una isla en las pantallas sin notch.
- Nook con widgets a tu gusto: Reproduciendo, A continuación, Clima, Enfoque, Batería y dispositivos, Atajos, Bandeja y Nota rápida.
- Reproduciendo para cualquier app de la sesión «Reproduciendo» del sistema, con letras sincronizadas y respaldo por AppleScript para Música y Spotify.
- Bandeja con arrastrar y soltar, AirDrop, compartir y conversiones en tu Mac, más el Bolsillo que aparece al agitar el puntero.
- Historial del portapapeles con búsqueda, filtros, fijados y pegado automático.
- Calendario con enlaces de reunión, Tareas sincronizadas con Recordatorios, Notas, Espejo, Teleprompter que sigue tu voz y Atajos.
- Pomodoro, temporizadores, cronómetro y sonidos de enfoque generados en tu Mac.
- Actividades en vivo para música, carga, dispositivos Bluetooth, volumen y brillo, descargas, reuniones, temporizadores y Bloq Mayús.
- Reemplazo opcional del indicador de volumen y brillo del sistema.
- Pestaña de Terminal con SwiftTerm, Acciones rápidas (mantener despierto, cuentagotas, captura a la Bandeja, bloquear la pantalla, modo oscuro), Vista rápida en la Bandeja y letras sincronizadas bajo la isla.
- Actualizaciones automáticas con Sparkle, firmadas con EdDSA y servidas desde isla.kyrosrd.com.
- Ícono nuevo de la app.
- Español e inglés.
