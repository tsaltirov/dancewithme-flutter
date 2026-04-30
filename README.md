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

*Este documento se irá actualizando conforme avance el desarrollo.*
