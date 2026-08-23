---
title: Preguntas de AppSec para nivel mid
description: Preguntas frecuentes de seguridad de aplicaciones con respuestas de referencia.
tema: desarrollo-seguro
tags: ['appsec', 'entrevista', 'owasp']
nivel: mid
categoria: AppSec
publishDate: 2026-08-12
---

Una selección de preguntas típicas de entrevista de **seguridad de aplicaciones** para un perfil
intermedio, con respuestas modelo.

## 1. ¿Cuál es la diferencia entre autenticación y autorización?

**Autenticación** verifica *quién eres* (validar credenciales). **Autorización** verifica *qué
puedes hacer* (permisos sobre recursos). Un fallo común es autenticar bien pero no comprobar la
autorización en cada acción (IDOR / *broken access control*).

## 2. ¿Cómo prevendrías un ataque XSS?

- Codificación de salida según contexto (HTML, atributo, JS, URL).
- `Content-Security-Policy` restrictiva.
- Evitar `innerHTML` / `dangerouslySetInnerHTML` con datos no confiables.
- Cookies de sesión con `HttpOnly` para limitar el impacto.

## 3. ¿Qué es CSRF y cómo se mitiga?

Un atacante induce al navegador de la víctima a enviar una petición autenticada no deseada.
Mitigaciones: tokens anti-CSRF, cookies `SameSite=Lax/Strict`, y verificar el header `Origin`.

## 4. ¿Dónde guardarías un token de sesión en el navegador?

Preferible una **cookie `HttpOnly` + `Secure` + `SameSite`** frente a `localStorage`, porque
esta última es accesible por JavaScript y por tanto expuesta a XSS.

## 5. ¿Qué revisas en un code review desde la óptica de seguridad?

Entrada no validada, secretos hardcodeados, consultas sin parametrizar, controles de acceso
ausentes, logging de datos sensibles y dependencias desactualizadas.
