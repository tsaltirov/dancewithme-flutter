# DanceWithMe

Aplicación multiplataforma desarrollada en **Flutter** para la gestión de academias de baile. Permite a los propietarios administrar sus escuelas, ver estadísticas y gestionar accesos, con soporte para móvil, tablet y web desde una única base de código.

---

## Características principales

- **Autenticación completa** — inicio de sesión, recuperación de contraseña mediante código OTP y restablecimiento seguro
- **Gestión de escuelas** — listado, creación y subida de imagen de portada por academia
- **Diseño adaptativo** — layouts diferenciados para móvil (< 600 px), tablet (600–1099 px) y web (≥ 1100 px)
- **Multiidioma** — inglés, español y búlgaro con cambio de idioma en tiempo real desde la pantalla de login
- **Almacenamiento seguro** — tokens JWT guardados con cifrado nativo mediante `flutter_secure_storage`
- **Subida de imágenes** — integración con Supabase Storage para las fotos de las academias

---

## Tecnologías y dependencias principales

| Categoría | Paquete | Uso |
|---|---|---|
| Backend / Storage | `supabase_flutter` | Almacenamiento de imágenes (bucket `dancewithme`) |
| API REST | `http` | Llamadas al backend propio (`BACKEND_URL`) |
| Traducciones | `easy_localization` | Archivos JSON por idioma en `assets/translations/` |
| Variables de entorno | `flutter_dotenv` | Lectura del fichero `.env` |
| Almacenamiento seguro | `flutter_secure_storage` | Persistencia de tokens de sesión |
| Tipografías | `google_fonts` | Outfit (auth) · Plus Jakarta Sans (home) |
| Imagen del dispositivo | `image_picker` | Selección de foto al crear una academia |
| Navegación | `go_router` | Enrutamiento declarativo |

---

### 1. Variables de entorno

Crea un fichero `.env` en la raíz del proyecto:

```env
BACKEND_URL=
SUPABASE_URL=
SUPABASE_TOKEN=

2. Instalar dependencias

flutter pub get

3. Ejecutar

flutter run

Traducciones
Las traducciones se gestionan con easy_localization. Los ficheros JSON se encuentran en assets/translations/ con la clave de idioma como nombre (en.json, es.json, bg.json).

El idioma se puede cambiar en tiempo real desde la pantalla de login mediante el selector de idioma en la esquina superior derecha. El idioma de respaldo (fallback) es el inglés.

Para añadir una nueva clave de traducción, agrégala en los tres ficheros manteniendo la misma estructura de claves anidadas.

---

## Módulos implementados

### Autenticación
- Login con email/contraseña y JWT
- Recuperación de contraseña por código OTP (6 dígitos)
- Restablecimiento de contraseña
- **Refresh automático de tokens** — `AuthService.getAccessToken()` decodifica el claim `exp` del JWT sin librería de crypto, refresca proactivamente 60 s antes de expirar y serializa las llamadas concurrentes con un `Completer` para que nunca se lancen dos refresh simultáneos.

### Pantalla principal (Home)
- Listado de academias con estadísticas globales (alumnos, eventos)
- Layouts diferenciados: móvil · tablet (barra flotante) · web (sidebar fijo)
- Navegación a la academia con transición SharedAxis

### Gestión de academia (School Screen)
Pantalla con pestañas que varía su estructura según el breakpoint:

| Pestaña | Descripción |
|---|---|
| **Alumnos** | Lista virtual (`SliverList`) con carga en 2 fases: datos inmediatos + estado de pagos en background |
| **Eventos** | CRUD completo, inscripción de alumnos, gestión de precios, cancelación |
| **Grupos** | CRUD, inscripción de alumnos, niveles y horarios |
| **Vestuario** | Catálogo de prendas + asignaciones a eventos (ver más abajo) |
| **Coreografías** | Placeholder — pendiente |
| **Alertas** | Placeholder — pendiente |

### Pagos
- Registro de pagos con método (efectivo, transferencia, tarjeta, domiciliación)-> Solo strings NO es pago real    con pasarela.
- Filtro por periodo (año/mes) con estado PAGADO / PENDIENTE
- "Cobro"/Check de pagos pendientes con confirmación.

### Módulo de Vestuario (Wardrobe)
El módulo más completo. Dos conceptos separados:

**Catálogo vestuario**
- Lista prendas activas e inactivas del centro.
- Filtros: Todos / Activos / Inactivos
- Badge `asignados/total` en cada card con semáforo de color
- CRUD completo: crear, editar (PUT), activar (PATCH `/activate`), desactivar (DELETE soft)
- Subida de imagen: galería o **cámara** (en web solo galería, detectado con `kIsWeb`)

**Asignaciones**
- Asignar traje a alumno inscrito en un evento (bottom sheet 2 pasos: evento → participación)
- Sección de asignaciones con 2 pestañas: **Entregados** (ENTREGADO / PENDIENTE_DEVOLUCION) y **Devueltos** (DEVUELTO)
- Devolución con diálogo de confirmación que muestra traje, alumno, evento y observaciones.

---

*Este documento se irá actualizando conforme avance el desarrollo.*
