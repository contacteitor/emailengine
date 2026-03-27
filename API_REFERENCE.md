# EmailEngine API Reference

> Documentacion completa de la REST API de EmailEngine para integracion con servicios externos.

## Informacion General

- **Base URL**: `http://{host}:{port}` (default: `http://127.0.0.1:3000`)
- **Prefijo API**: `/v1`
- **Autenticacion**: Bearer token via header `Authorization: Bearer {token}` o query param `?access_token={token}`
- **Content-Type**: `application/json`
- **Timeout**: 10s por defecto, configurable con header `X-EE-Timeout` (max 7,200,000 ms)
- **Idempotencia**: Header opcional `Idempotency-Key` para prevenir duplicados (max 256 chars)
- **Paginacion**: `page` (0-based, default: 0), `pageSize` (1-1000, default: 20)

---

## Autenticacion

Todas las rutas `/v1/*` requieren un token API. Metodos soportados:

```
# Header (recomendado)
Authorization: Bearer {token}

# Query parameter
GET /v1/accounts?access_token={token}
```

**Scopes de tokens**: `api`, `metrics`, `smtp`, `imap-proxy`, `*` (todos)

---

## Schemas Reutilizables

### Email Address Object

```json
{
  "name": "John Doe",       // string, opcional, max 256 chars
  "address": "john@example.com"  // string, requerido, email valido
}
```

### IMAP Configuration

```json
{
  "auth": {
    "user": "user@example.com",   // string, requerido, max 256
    "pass": "password123"          // string, requerido si no hay accessToken, max 256
  },
  "host": "imap.gmail.com",       // string, requerido
  "port": 993,                     // number, 1-65535
  "secure": true,                  // boolean, default false
  "tls": {
    "rejectUnauthorized": true,    // boolean, default true
    "minVersion": "TLSv1.2"       // string, opcional
  },
  "resyncDelay": 900,             // number, segundos entre resync, default 900
  "disabled": false,               // boolean, deshabilitar temporalmente
  "sentMailPath": null,            // string, path custom para Sent
  "draftsMailPath": null,
  "junkMailPath": null,
  "trashMailPath": null,
  "archiveMailPath": null
}
```

### SMTP Configuration

```json
{
  "auth": {
    "user": "user@example.com",
    "pass": "password123"
  },
  "host": "smtp.gmail.com",
  "port": 587,
  "secure": false,
  "tls": {
    "rejectUnauthorized": true,
    "minVersion": "TLSv1.2"
  }
}
```

### OAuth2 Configuration

```json
{
  "authorize": true,               // boolean, solicitar URL de autorizacion
  "redirectUrl": "https://...",     // string, URL de redireccion post-auth
  "provider": "gmail",             // string, ID de app OAuth2 configurada
  "auth": {
    "user": "user@gmail.com",      // string, requerido
    "delegatedUser": null,          // string, para shared mailboxes (MS365)
    "delegatedAccount": null        // string, account ID para delegacion
  },
  "accessToken": "ya29...",        // string, max 16KB
  "refreshToken": "1//...",        // string, max 16KB
  "expires": "2024-01-01T00:00:00Z"  // date ISO 8601
}
```

### Search Query Object

```json
{
  "seq": "1:10",              // string, rango de secuencia (solo IMAP)
  "answered": true,           // boolean (solo IMAP)
  "deleted": false,           // boolean (solo IMAP)
  "draft": false,             // boolean
  "unseen": true,             // boolean
  "flagged": false,           // boolean
  "seen": false,              // boolean
  "from": "sender@example.com",  // string, max 256
  "to": "recipient@example.com", // string, max 256 (no soportado MS Graph)
  "cc": "",                       // string, max 256 (no soportado MS Graph)
  "bcc": "",                      // string, max 256 (no soportado MS Graph)
  "body": "keyword",              // string, max 256
  "subject": "meeting",           // string, max 2560
  "larger": 1024,                 // number, bytes, 0-1GB (no MS Graph)
  "smaller": 1048576,             // number, bytes, 0-1GB (no MS Graph)
  "uid": "100:200",               // string, rango UID (solo IMAP)
  "modseq": 12345,                // number (IMAP con CONDSTORE)
  "before": "2024-06-01T00:00:00Z",   // date ISO
  "since": "2024-01-01T00:00:00Z",    // date ISO
  "sentBefore": "2024-06-01T00:00:00Z",
  "sentSince": "2024-01-01T00:00:00Z",
  "emailId": "abc123",           // string
  "threadId": "thread123",       // string
  "header": {                     // object, headers especificos
    "Message-ID": "<value@example.com>"
  },
  "gmailRaw": "in:inbox is:unread",  // string, max 1024 (solo Gmail)
  "emailIds": ["id1", "id2"]         // array de strings
}
```

---

## 1. Cuentas (Accounts)

### POST /v1/account - Crear cuenta

Registra una nueva cuenta de email.

**Request Body:**
```json
{
  "account": "my-account-id",         // string, max 256, lowercase. null = auto-generado
  "name": "My Email Account",          // string, requerido, max 256
  "email": "user@example.com",         // string, email valido
  "path": ["*"],                        // array de strings, carpetas a monitorear
  "subconnections": ["Sent"],           // array, carpetas con conexion IMAP dedicada
  "webhooks": "https://my-app.com/webhook",  // string, URL webhook
  "copy": true,                         // boolean, copiar a Sent folder
  "logs": false,                        // boolean, almacenar logs recientes
  "notifyFrom": "2024-01-01T00:00:00Z", // date, webhooks solo para mensajes despues de esta fecha
  "syncFrom": "2024-01-01T00:00:00Z",   // date, inicio de sincronizacion
  "proxy": "socks5://proxy:1080",        // string, URL de proxy
  "smtpEhloName": "mail.example.com",    // string, hostname para SMTP EHLO
  "imapIndexer": "full",                  // string, "full" o "fast"
  "imap": { /* ver IMAP Configuration */ },
  "smtp": { /* ver SMTP Configuration */ },
  "oauth2": { /* ver OAuth2 Configuration */ },
  "webhooksCustomHeaders": [
    { "key": "X-Custom", "value": "value" }
  ],
  "locale": "es",
  "tz": "America/Mexico_City"
}
```

**Response 200:**
```json
{
  "account": "my-account-id",
  "state": "new"              // "new" o "existing"
}
```

---

### PUT /v1/account/{account} - Actualizar cuenta

**Path params:** `account` (string, requerido)

**Request Body:** Mismos campos que POST pero todos opcionales (sin `account`).

**Response 200:**
```json
{
  "account": "my-account-id"
}
```

---

### GET /v1/account/{account} - Obtener informacion de cuenta

**Path params:** `account` (string, requerido)

**Query params:**
- `quota` (boolean) - Incluir informacion de quota (solo IMAP)

**Response 200:**
```json
{
  "account": "my-account-id",
  "name": "My Email Account",
  "email": "user@example.com",
  "state": "connected",
  "type": "imap",
  "imap": { "host": "...", "port": 993, "secure": true },
  "smtp": { "host": "...", "port": 587 },
  "counters": { "messages": 1500 },
  "syncTime": "2024-01-15T10:30:00Z",
  "quota": { "usage": 5000000, "limit": 15000000000 }
}
```

---

### GET /v1/accounts - Listar cuentas

**Query params:**
- `page` (number, default: 0)
- `pageSize` (number, default: 20, max: 1000)
- `state` (string) - Filtrar por estado
- `query` (string) - Buscar por nombre/email

**Response 200:**
```json
{
  "total": 50,
  "page": 0,
  "pages": 3,
  "accounts": [
    {
      "account": "account-id",
      "name": "Account Name",
      "email": "user@example.com",
      "state": "connected",
      "type": "imap"
    }
  ]
}
```

---

### DELETE /v1/account/{account} - Eliminar cuenta

**Path params:** `account` (string, requerido)

**Response 200:**
```json
{
  "account": "my-account-id",
  "deleted": true
}
```

---

### PUT /v1/account/{account}/reconnect - Reconectar cuenta

**Path params:** `account` (string, requerido)

**Request Body:**
```json
{ "reconnect": true }
```

**Response 200:**
```json
{ "reconnect": true }
```

---

### PUT /v1/account/{account}/sync - Forzar sincronizacion

Solo para cuentas IMAP.

**Path params:** `account` (string, requerido)

**Request Body:**
```json
{ "sync": true }
```

**Response 200:**
```json
{ "sync": true }
```

---

### PUT /v1/account/{account}/flush - Flush de indices

Elimina todos los indices de email de Redis y recrea el indice.

**Path params:** `account` (string, requerido)

**Request Body:**
```json
{
  "flush": true,
  "notifyFrom": "2024-01-01T00:00:00Z",
  "syncFrom": "2024-01-01T00:00:00Z",
  "imapIndexer": "full"
}
```

**Response 200:**
```json
{ "flush": true }
```

---

## 2. Buzones (Mailboxes)

### GET /v1/account/{account}/mailboxes - Listar buzones

**Path params:** `account` (string, requerido)

**Response 200:**
```json
{
  "mailboxes": [
    {
      "path": "INBOX",
      "name": "INBOX",
      "specialUse": "\\Inbox",
      "listed": true,
      "subscribed": true,
      "messages": 150,
      "uidNext": 200
    },
    {
      "path": "[Gmail]/Sent Mail",
      "name": "Sent Mail",
      "specialUse": "\\Sent",
      "listed": true,
      "messages": 500
    }
  ]
}
```

---

### POST /v1/account/{account}/mailbox - Crear buzon

**Path params:** `account` (string, requerido)

**Request Body:**
```json
{
  "path": ["Projects", "2024"]   // array de strings, componentes del path
}
```

---

### PUT /v1/account/{account}/mailbox - Modificar buzon

**Path params:** `account` (string, requerido)

**Request Body:**
```json
{
  "path": "OldFolder",
  "newPath": "NewFolder"
}
```

---

### DELETE /v1/account/{account}/mailbox - Eliminar buzon

**Path params:** `account` (string, requerido)

**Query params:** `path` (string, requerido) - Path del buzon a eliminar

---

## 3. Mensajes (Messages)

### GET /v1/account/{account}/messages - Listar mensajes

**Path params:** `account` (string, requerido)

**Query params:**
- `path` (string, **requerido**) - Path del buzon (ej: "INBOX")
- `cursor` (string) - Cursor para paginacion basada en cursor
- `page` (number, default: 0)
- `pageSize` (number, default: 20, max: 1000)

**Response 200:**
```json
{
  "total": 150,
  "page": 0,
  "pages": 8,
  "messages": [
    {
      "id": "AAAAAQAAABc",
      "uid": 23,
      "emailId": "email-id-123",
      "threadId": "thread-id-456",
      "date": "2024-01-15T10:30:00Z",
      "flags": ["\\Seen"],
      "labels": [],
      "unseen": false,
      "size": 2048,
      "subject": "Meeting tomorrow",
      "from": { "name": "John", "address": "john@example.com" },
      "to": [{ "name": "Jane", "address": "jane@example.com" }],
      "messageId": "<abc123@example.com>",
      "attachments": []
    }
  ]
}
```

---

### GET /v1/account/{account}/message/{message} - Obtener mensaje

**Path params:**
- `account` (string, requerido)
- `message` (string, requerido) - ID del mensaje (encodedId)

**Query params:**
- `maxBytes` (number) - Limite de bytes para contenido de texto
- `textType` (string) - "html", "plain", o "*" (ambos). Default: "*"
- `webSafeHtml` (boolean) - Sanitizar HTML para visualizacion web
- `embedAttachedImages` (boolean) - Incrustar imagenes como data URIs
- `preProcessHtml` (boolean) - Pre-procesar HTML
- `markAsSeen` (boolean) - Marcar como leido al obtener

**Response 200:**
```json
{
  "id": "AAAAAQAAABc",
  "uid": 23,
  "emailId": "email-id-123",
  "threadId": "thread-id-456",
  "date": "2024-01-15T10:30:00Z",
  "flags": ["\\Seen"],
  "labels": [],
  "size": 15360,
  "subject": "Meeting tomorrow",
  "from": { "name": "John Doe", "address": "john@example.com" },
  "to": [{ "name": "Jane Smith", "address": "jane@example.com" }],
  "cc": [],
  "bcc": [],
  "replyTo": [],
  "messageId": "<abc123@example.com>",
  "inReplyTo": null,
  "references": [],
  "text": {
    "id": "text-id-123",
    "plain": "Hello, let's meet tomorrow at 10am.",
    "html": "<p>Hello, let's meet tomorrow at 10am.</p>",
    "hasMore": false
  },
  "attachments": [
    {
      "id": "att-id-123",
      "contentType": "application/pdf",
      "filename": "agenda.pdf",
      "encodedSize": 12345,
      "embedded": false
    }
  ],
  "headers": {}
}
```

---

### GET /v1/account/{account}/message/{message}/source - Descargar mensaje raw

Devuelve el mensaje RFC822 completo como stream.

**Path params:**
- `account` (string, requerido)
- `message` (string, requerido)

**Response**: `message/rfc822` binary stream

---

### GET /v1/account/{account}/text/{text} - Obtener texto de mensaje

**Path params:**
- `account` (string, requerido)
- `text` (string, requerido) - ID del texto

**Query params:**
- `maxBytes` (number)
- `textType` (string) - Default: "*"

**Response 200:**
```json
{
  "plain": "Texto plano del mensaje...",
  "html": "<p>Texto HTML del mensaje...</p>",
  "hasMore": false
}
```

---

### GET /v1/account/{account}/attachment/{attachment} - Descargar adjunto

**Path params:**
- `account` (string, requerido)
- `attachment` (string, requerido) - ID del adjunto

**Response**: `application/octet-stream` binary stream

---

### POST /v1/account/{account}/message - Subir mensaje

Sube un mensaje y lo almacena en un buzon.

**Path params:** `account` (string, requerido)

**Request Body:**
```json
{
  "path": "INBOX",                          // string, requerido
  "flags": ["\\Seen"],                      // array, opcional
  "internalDate": "2024-01-15T10:30:00Z",  // date, opcional
  "raw": "base64-encoded-rfc822...",         // string, opcional (sobreescribe otros campos)
  "from": { "name": "John", "address": "john@example.com" },
  "to": [{ "name": "Jane", "address": "jane@example.com" }],
  "cc": [],
  "bcc": [],
  "replyTo": [],
  "subject": "Test message",               // string, max 10KB
  "text": "Plain text content",            // string
  "html": "<p>HTML content</p>",           // string
  "attachments": [
    {
      "filename": "file.pdf",              // string, requerido, max 256
      "content": "base64-encoded...",       // string, requerido (base64)
      "contentType": "application/pdf"      // string, opcional
    }
  ],
  "messageId": "<custom-id@example.com>",  // string, max 996
  "headers": { "X-Custom": "value" },      // object, headers custom
  "locale": "es",
  "tz": "America/Mexico_City"
}
```

**Response 200:**
```json
{
  "path": "INBOX",
  "id": "AAAAAQAAABc",
  "uid": 24,
  "uidValidity": "1234567890",
  "seq": 151,
  "messageId": "<custom-id@example.com>"
}
```

---

### POST /v1/account/{account}/submit - Enviar mensaje

Encola un email para envio asincrono via SMTP o API de proveedor.

**Path params:** `account` (string, requerido)

**Request Body:**
```json
{
  "from": { "name": "John", "address": "john@example.com" },
  "to": [{ "name": "Jane", "address": "jane@example.com" }],
  "cc": [],
  "bcc": [],
  "replyTo": [],
  "subject": "Hello from EmailEngine",
  "text": "Plain text version",
  "html": "<h1>Hello!</h1><p>HTML version</p>",
  "attachments": [
    {
      "filename": "document.pdf",
      "content": "base64-encoded-content",
      "contentType": "application/pdf"
    }
  ],
  "headers": { "X-Custom-Header": "value" },
  "messageId": "<custom-msg-id@example.com>",
  "reference": {
    "message": "original-msg-id",
    "action": "reply",                    // "reply", "replyAll", "forward"
    "inline": false
  },
  "locale": "es",
  "tz": "America/Mexico_City"
}
```

**Response 200:**
```json
{
  "queueId": "queue-id-123",
  "messageId": "<custom-msg-id@example.com>",
  "sendAt": "2024-01-15T10:31:00Z"
}
```

---

### PUT /v1/account/{account}/message/{message} - Actualizar mensaje

Actualiza flags y labels de un mensaje.

**Path params:**
- `account` (string, requerido)
- `message` (string, requerido)

**Request Body:**
```json
{
  "flags": {
    "add": ["\\Seen"],           // flags a agregar
    "delete": ["\\Flagged"],     // flags a eliminar
    "set": ["\\Seen"]            // reemplazar todos los flags
  },
  "labels": {
    "add": ["Important"],        // labels a agregar (Gmail)
    "delete": ["Promotions"],    // labels a eliminar
    "set": ["INBOX", "Important"] // reemplazar todos los labels
  }
}
```

**Response 200:**
```json
{
  "flags": { "add": ["\\Seen"], "delete": [], "set": [] },
  "labels": { "add": [], "delete": [], "set": [] }
}
```

---

### PUT /v1/account/{account}/messages - Actualizar multiples mensajes

**Path params:** `account` (string, requerido)

**Query params:** `path` (string, **requerido**) - Path del buzon

**Request Body:**
```json
{
  "search": { "unseen": true },
  "update": {
    "flags": { "add": ["\\Seen"] }
  }
}
```

---

### PUT /v1/account/{account}/message/{message}/move - Mover mensaje

**Path params:**
- `account` (string, requerido)
- `message` (string, requerido)

**Request Body:**
```json
{
  "path": "Archive"           // string, requerido, carpeta destino
}
```

**Response 200:**
```json
{
  "path": "Archive",
  "id": "new-encoded-id",
  "uid": 45
}
```

---

### PUT /v1/account/{account}/messages/move - Mover multiples mensajes

**Path params:** `account` (string, requerido)

**Query params:** `path` (string, **requerido**) - Carpeta origen

**Request Body:**
```json
{
  "search": { "flagged": true },
  "path": "Important"
}
```

---

### DELETE /v1/account/{account}/message/{message} - Eliminar mensaje

Mueve a Trash, o elimina permanentemente si ya esta en Trash.

**Path params:**
- `account` (string, requerido)
- `message` (string, requerido)

**Query params:**
- `force` (boolean) - Forzar eliminacion permanente

**Response 200:**
```json
{
  "deleted": true,
  "moved": {
    "destination": "Trash",
    "message": "new-msg-id"
  }
}
```

---

### PUT /v1/account/{account}/messages/delete - Eliminar multiples mensajes

**Path params:** `account` (string, requerido)

**Query params:**
- `path` (string, **requerido**) - Carpeta origen
- `force` (boolean)

**Request Body:**
```json
{
  "search": { "before": "2023-01-01T00:00:00Z" }
}
```

---

### POST /v1/account/{account}/search - Buscar mensajes

**Path params:** `account` (string, requerido)

**Query params:**
- `path` (string) - Carpeta donde buscar (opcional si usa documentStore)
- `cursor` (string)
- `page` (number)
- `pageSize` (number)

**Request Body:**
```json
{
  "search": {
    "unseen": true,
    "from": "john@example.com",
    "since": "2024-01-01T00:00:00Z",
    "subject": "meeting"
  }
}
```

**Response 200:** Mismo formato que listar mensajes.

---

## 4. Templates

### POST /v1/templates/template - Crear template

**Request Body:**
```json
{
  "account": "my-account",           // string, null = template publico
  "name": "Welcome Email",           // string, requerido, max 256
  "description": "Sent to new users", // string, max 1024
  "format": "html",                   // "html" o "markdown", default "html"
  "content": {
    "subject": "Welcome {{name}}!",   // string, max 10KB
    "text": "Hello {{name}}, welcome!",
    "html": "<h1>Welcome {{name}}!</h1>",
    "previewText": "Welcome aboard"    // string, max 1024
  }
}
```

**Response 200:**
```json
{
  "created": true,
  "account": "my-account",
  "id": "template-id-123"
}
```

---

### GET /v1/templates - Listar templates

**Query params:**
- `account` (string) - Filtrar por cuenta
- `page` (number)
- `pageSize` (number)

**Response 200:**
```json
{
  "account": "my-account",
  "total": 5,
  "page": 0,
  "pages": 1,
  "templates": [
    {
      "id": "template-id-123",
      "name": "Welcome Email",
      "description": "Sent to new users",
      "format": "html",
      "created": "2024-01-15T10:30:00Z",
      "updated": "2024-01-16T08:00:00Z"
    }
  ]
}
```

---

### GET /v1/templates/template/{template} - Obtener template

**Path params:** `template` (string, requerido)

**Response 200:**
```json
{
  "account": "my-account",
  "id": "template-id-123",
  "name": "Welcome Email",
  "description": "Sent to new users",
  "format": "html",
  "created": "2024-01-15T10:30:00Z",
  "updated": "2024-01-16T08:00:00Z",
  "content": {
    "subject": "Welcome {{name}}!",
    "text": "Hello {{name}}, welcome!",
    "html": "<h1>Welcome {{name}}!</h1>",
    "previewText": "Welcome aboard"
  }
}
```

---

### PUT /v1/templates/template/{template} - Actualizar template

**Path params:** `template` (string, requerido)

**Request Body:** Mismos campos que POST, todos opcionales.

---

### DELETE /v1/templates/template/{template} - Eliminar template

**Path params:** `template` (string, requerido)

**Response 200:**
```json
{
  "deleted": true,
  "account": "my-account",
  "id": "template-id-123"
}
```

---

### DELETE /v1/templates/account/{account} - Eliminar todos los templates de una cuenta

**Path params:** `account` (string, requerido)

**Query params:** `force` (boolean, **requerido**) - Debe ser `true`

---

## 5. Export (Beta)

### POST /v1/account/{account}/export - Crear exportacion

**Path params:** `account` (string, requerido)

**Request Body:**
```json
{
  "folders": ["INBOX", "\\Sent"],            // array, opcional. Vacio = todas las carpetas
  "startDate": "2024-01-01T00:00:00Z",      // date, requerido
  "endDate": "2024-12-31T23:59:59Z",        // date, requerido (debe ser > startDate)
  "textType": "*",                            // "plain", "html", "*". Default: "*"
  "maxBytes": 5242880,                        // number, max bytes texto. 0 = ilimitado
  "includeAttachments": false                 // boolean, incluir adjuntos base64. Default: false
}
```

**Response 200:**
```json
{
  "exportId": "exp_abc123def456",
  "status": "queued",
  "created": "2024-01-15T10:30:00Z"
}
```

---

### GET /v1/account/{account}/export/{exportId} - Estado de exportacion

**Response 200:**
```json
{
  "exportId": "exp_abc123def456",
  "status": "completed",
  "created": "2024-01-15T10:30:00Z",
  "completed": "2024-01-15T10:45:00Z",
  "progress": {
    "phase": "complete",
    "messagesTotal": 1000,
    "messagesExported": 995,
    "messagesSkipped": 5,
    "bytesWritten": 52428800
  }
}
```

Estados posibles: `queued`, `processing`, `completed`, `failed`, `cancelled`

---

### GET /v1/account/{account}/export/{exportId}/download - Descargar exportacion

**Response**: `application/gzip` - Archivo NDJSON comprimido con gzip.

---

### GET /v1/account/{account}/exports - Listar exportaciones

**Query params:** `page`, `pageSize`

---

### DELETE /v1/account/{account}/export/{exportId} - Cancelar/eliminar exportacion

---

## 6. Tokens

### POST /v1/token - Crear token

**Request Body:**
```json
{
  "description": "API access for my app",
  "scopes": ["api"],                     // array: "api", "metrics", "smtp", "imap-proxy", "*"
  "restrictions": {
    "ip": ["192.168.1.0/24"],            // array, restricciones IP
    "ttl": 86400                          // number, time-to-live en segundos
  }
}
```

**Response 200:**
```json
{
  "token": "64-char-hex-token",
  "description": "API access for my app"
}
```

---

### GET /v1/tokens - Listar tokens root

**Query params:** `page`, `pageSize`

---

### GET /v1/tokens/account/{account} - Listar tokens de una cuenta

---

### DELETE /v1/token/{token} - Eliminar token

---

## 7. Webhooks

### GET /v1/webhookRoutes - Listar rutas de webhook

**Query params:** `page`, `pageSize`

**Response 200:**
```json
{
  "total": 3,
  "page": 0,
  "pages": 1,
  "webhooks": [
    {
      "id": "webhook-route-id",
      "name": "New messages webhook",
      "targetUrl": "https://my-app.com/webhook",
      "enabled": true
    }
  ]
}
```

---

### GET /v1/webhookRoutes/webhookRoute/{webhookRoute} - Obtener ruta de webhook

---

### Eventos de Webhook Soportados

| Evento | Descripcion |
|--------|-------------|
| `messageNew` | Nuevo mensaje recibido |
| `messageDeleted` | Mensaje eliminado |
| `messageUpdated` | Flags/labels de mensaje actualizados |
| `messageSent` | Mensaje enviado exitosamente |
| `messageDeliveryError` | Error de envio (reintentable) |
| `messageFailed` | Envio fallido definitivamente |
| `messageBounce` | Mensaje rebotado |
| `messageComplaint` | Queja de spam recibida |
| `mailboxNew` | Nuevo buzon creado |
| `mailboxDeleted` | Buzon eliminado |
| `mailboxReset` | Buzon reseteado |
| `accountAdded` | Cuenta agregada |
| `accountInitialized` | Cuenta inicializada |
| `accountDeleted` | Cuenta eliminada |
| `authenticationError` | Error de autenticacion |
| `authenticationSuccess` | Autenticacion exitosa |
| `connectError` | Error de conexion |
| `trackOpen` | Email abierto (tracking) |
| `trackClick` | Link clickeado (tracking) |
| `exportCompleted` | Exportacion completada |
| `exportFailed` | Exportacion fallida |

**Firma de webhooks**: Header `X-EE-Wh-Signature` con HMAC-SHA256 del body.

---

## 8. OAuth2 Applications

### GET /v1/oauth2 - Listar aplicaciones OAuth2

### GET /v1/oauth2/{app} - Obtener aplicacion

### POST /v1/oauth2 - Registrar aplicacion OAuth2

**Request Body:**
```json
{
  "name": "My Gmail App",
  "provider": "gmail",                 // "gmail", "outlook", "mailRu"
  "clientId": "client-id.apps.googleusercontent.com",
  "clientSecret": "client-secret",
  "redirectUrl": "https://my-app.com/oauth/callback",
  "scopes": ["https://mail.google.com/"]
}
```

### PUT /v1/oauth2/{app} - Actualizar aplicacion

### DELETE /v1/oauth2/{app} - Eliminar aplicacion

---

## 9. Gateways (SMTP)

### GET /v1/gateways - Listar gateways

### GET /v1/gateway/{gateway} - Obtener gateway

### POST /v1/gateway - Crear gateway

**Request Body:**
```json
{
  "name": "SendGrid",
  "host": "smtp.sendgrid.net",
  "port": 587,
  "secure": false,
  "auth": {
    "user": "apikey",
    "pass": "SG.xxxx"
  }
}
```

### PUT /v1/gateway/edit/{gateway} - Actualizar gateway

### DELETE /v1/gateway/{gateway} - Eliminar gateway

---

## 10. Outbox (Cola de envio)

### GET /v1/outbox - Listar mensajes en cola

**Query params:** `page`, `pageSize`

### GET /v1/outbox/{queueId} - Obtener mensaje en cola

### DELETE /v1/outbox/{queueId} - Eliminar mensaje de la cola

---

## 11. Settings

### GET /v1/settings - Obtener configuracion

**Query params:** `key` (array de strings) - Claves a obtener

Claves disponibles:
- `webhooksEnabled` - Webhooks habilitados globalmente
- `webhooks` - URL de webhook global
- `webhookEvents` - Eventos de webhook habilitados
- `webhooksCustomHeaders` - Headers custom para webhooks
- `deliveryAttempts` - Intentos de envio (default: 10)
- `smtpServerEnabled` - Servidor SMTP habilitado
- `smtpServerPort` - Puerto SMTP
- `imapProxyServerEnabled` - Proxy IMAP habilitado
- `exportMaxAge` - Retencion de exports (default: 7 dias)

### POST /v1/settings - Actualizar configuracion

**Request Body:**
```json
{
  "webhooksEnabled": true,
  "webhooks": "https://my-app.com/webhook",
  "webhookEvents": ["messageNew", "messageSent"],
  "deliveryAttempts": 5
}
```

---

## 12. Utilidades

### GET /health - Health check

No requiere autenticacion.

**Response 200:**
```json
{ "status": "ok" }
```

---

### GET /v1/stats - Estadisticas del servidor

**Response 200:**
```json
{
  "uptime": 86400,
  "accounts": { "total": 50, "connected": 48 },
  "queues": { "submit": 0, "notify": 0 },
  "memory": { "rss": 150000000, "heapUsed": 100000000 }
}
```

---

### POST /v1/verifyAccount - Verificar configuracion

Prueba la conectividad IMAP/SMTP sin crear la cuenta.

**Request Body:**
```json
{
  "imap": {
    "auth": { "user": "test@example.com", "pass": "password" },
    "host": "imap.example.com",
    "port": 993,
    "secure": true
  },
  "smtp": {
    "auth": { "user": "test@example.com", "pass": "password" },
    "host": "smtp.example.com",
    "port": 587,
    "secure": false
  }
}
```

---

### GET /v1/autoconfig - Auto-descubrir configuracion

**Query params:** `domain` (string) - Dominio de email (ej: "gmail.com")

---

### GET /v1/account/{account}/oauth-token - Obtener token OAuth2 actual

Devuelve el access token OAuth2 vigente de la cuenta.

---

### GET /v1/account/{account}/server-signatures - Listar firmas del servidor

---

### GET /v1/account/{account}/logs - Obtener logs IMAP

---

### GET /v1/logs/{account} - Obtener logs de cuenta

---

### GET /v1/changes - Stream de cambios (SSE)

Server-Sent Events para cambios de estado en tiempo real.

---

### GET /metrics - Metricas Prometheus

Requiere token con scope `metrics`.

---

## 13. Blocklists

### GET /v1/blocklists - Listar blocklists

### GET /v1/blocklist/{listId} - Obtener entradas de blocklist

### POST /v1/blocklist/{listId} - Agregar a blocklist

### DELETE /v1/blocklist/{listId} - Eliminar de blocklist

---

## 14. Delivery Tests

### POST /v1/delivery-test/account/{account} - Crear test de deliverability

### GET /v1/delivery-test/check/{deliveryTest} - Verificar resultado del test

---

## 15. License

### GET /v1/license - Obtener info de licencia

### POST /v1/license - Registrar licencia

**Request Body:**
```json
{ "license": "license-key-string" }
```

### DELETE /v1/license - Eliminar licencia

---

## 16. Queue Management

### GET /v1/settings/queue/{queue} - Info de cola

**Path params:** `queue` - Nombre de la cola (ej: "submit", "notify")

### PUT /v1/settings/queue/{queue} - Configurar cola

---

## 17. Authentication Form

### POST /v1/authentication/form - Generar link de autenticacion

Genera un formulario/link para que los usuarios autoricen sus cuentas de email.

**Request Body:**
```json
{
  "account": "account-id",
  "name": "User Name",
  "email": "user@example.com",
  "redirectUrl": "https://my-app.com/callback"
}
```

---

## 18. Pub/Sub

### GET /v1/pubsub/status - Estado de Pub/Sub

Muestra el estado de suscripciones Google Pub/Sub (para cuentas Gmail).

---

## Codigos de Error Comunes

| Status | Descripcion |
|--------|-------------|
| 400 | Bad Request - Parametros invalidos |
| 401 | Unauthorized - Token faltante o invalido |
| 403 | Forbidden - Token sin scope necesario |
| 404 | Not Found - Cuenta/mensaje no encontrado |
| 408 | Request Timeout - Operacion excedio timeout |
| 409 | Conflict - Recurso ya existe |
| 429 | Too Many Requests - Rate limit excedido |
| 500 | Internal Server Error |
| 503 | Service Unavailable - Cuenta desconectada |

**Formato de error:**
```json
{
  "statusCode": 404,
  "error": "Not Found",
  "message": "Account not found"
}
```

---

## Notas para Integracion

1. **Envio de emails es asincrono**: `POST /v1/account/{account}/submit` encola el mensaje. Usa webhooks (`messageSent`, `messageFailed`) para confirmar entrega.
2. **IDs de mensaje**: Los IDs son strings codificados internamente. Usalos tal como los devuelve la API.
3. **Fechas**: Siempre en formato ISO 8601 (ej: `2024-01-15T10:30:00Z`).
4. **Adjuntos**: Codificados en base64. Limite por defecto: 5MB por adjunto, 25MB total por mensaje.
5. **Webhooks**: Configura un endpoint que reciba POST con JSON. Verifica la firma `X-EE-Wh-Signature` para seguridad.
6. **Paginacion**: Usa `page` (0-based) y `pageSize`. Las respuestas incluyen `total` y `pages`.
7. **Timeout**: Para operaciones largas (busqueda, export), usa el header `X-EE-Timeout` con un valor mayor.
