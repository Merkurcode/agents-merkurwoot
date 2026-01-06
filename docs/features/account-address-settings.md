# Account Address Settings

## Descripción

Esta funcionalidad permite a los administradores de cuenta configurar la dirección física del establecimiento desde la página de configuración general. La información de dirección puede ser utilizada en plantillas y comunicaciones.

## Ubicación

- **URL**: `/app/accounts/:account_id/settings/general`
- **Sección**: "Dirección de la cuenta" (colapsable)

## Permisos

- **Solo administradores** pueden ver y modificar la información de dirección
- Los usuarios con otros roles no verán esta sección

## Campos disponibles

| Campo | Clave API | Requerido |
|-------|-----------|-----------|
| Calle | `street` | Sí |
| Número exterior | `exterior_number` | Sí |
| Número interior | `interior_number` | No |
| Colonia | `neighborhood` | Sí |
| Código postal | `postal_code` | Sí |
| Ciudad | `city` | Sí |
| Estado | `state` | Sí |
| Correo electrónico | `email` | No |
| Teléfono | `phone` | No |
| Página web | `webpage` | No |
| Resumen del establecimiento | `establishment_summary` | No |

## Archivos modificados

### Backend

**`app/controllers/api/v1/accounts_controller.rb`**

- Agregado método `account_address_params` para permitir parámetros de dirección
- Agregado método `update_account_address` para crear o actualizar la dirección
- Agregado método `administrator?` para verificar rol de administrador
- Modificado método `update` para procesar dirección solo si el usuario es administrador

```ruby
def update
  # ... existing code ...
  update_account_address if account_address_params.present? && administrator?
  @account.save!
end

def account_address_params
  params.permit(account_address: %i[id street exterior_number interior_number
    neighborhood postal_code city state email phone webpage
    establishment_summary])[:account_address]
end

def update_account_address
  address_params = account_address_params.to_h
  address_id = address_params.delete(:id)

  if address_id.present?
    address = @account.account_addresses.find_by(id: address_id)
    address&.update!(address_params)
  else
    @account.account_addresses.create!(address_params)
  end
end

def administrator?
  @current_account_user&.administrator?
end
```

### Frontend

**`app/javascript/dashboard/routes/dashboard/settings/account/components/AccountAddress.vue`** (nuevo)

Componente Vue 3 con Composition API que:
- Muestra un formulario colapsable (acordeón) con todos los campos de dirección
- Carga automáticamente los datos existentes al montar el componente
- Valida campos requeridos antes de enviar
- Envía los datos al API mediante el composable `useAccount`

**`app/javascript/dashboard/routes/dashboard/settings/account/Index.vue`**

- Importado y registrado el componente `AccountAddress`
- Agregado computed `isAdministrator` para verificar el rol
- Renderizado condicional: `<AccountAddress v-if="isAdministrator" />`

### Traducciones

**`app/javascript/dashboard/i18n/locale/en/generalSettings.json`**

```json
"ACCOUNT_ADDRESS": {
  "TITLE": "Account address",
  "NOTE": "Configure the physical address information for your account...",
  "STREET": "Street",
  "STREET_PLACEHOLDER": "Enter street name",
  // ... más campos
  "API": {
    "SUCCESS": "Account address updated successfully",
    "ERROR": "Failed to update account address"
  }
}
```

**`app/javascript/dashboard/i18n/locale/es/generalSettings.json`**

```json
"ACCOUNT_ADDRESS": {
  "TITLE": "Dirección de la cuenta",
  "NOTE": "Configura la información de dirección física de tu cuenta...",
  "STREET": "Calle",
  "STREET_PLACEHOLDER": "Ingresa el nombre de la calle",
  // ... más campos
  "API": {
    "SUCCESS": "Dirección de la cuenta actualizada correctamente",
    "ERROR": "Error al actualizar la dirección de la cuenta"
  }
}
```

## Flujo de datos

```
┌─────────────────────────────────────────────────────────────────┐
│                        Frontend (Vue)                           │
├─────────────────────────────────────────────────────────────────┤
│  1. AccountAddress.vue carga datos de currentAccount            │
│  2. Usuario modifica campos del formulario                      │
│  3. Al guardar, llama updateAccount() con account_address       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    API (Rails Controller)                        │
├─────────────────────────────────────────────────────────────────┤
│  4. accounts_controller#update recibe la petición               │
│  5. Verifica que usuario sea administrador                      │
│  6. Si account_address tiene ID, actualiza; si no, crea         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Base de datos                              │
├─────────────────────────────────────────────────────────────────┤
│  7. AccountAddress se guarda/actualiza en la tabla              │
│  8. La respuesta incluye account_address en el JSON             │
└─────────────────────────────────────────────────────────────────┘
```

## Modelo de datos

El modelo `AccountAddress` ya existía y está asociado a `Account`:

```ruby
# app/models/account.rb
has_many :account_addresses, dependent: :destroy

# app/models/account_address.rb
belongs_to :account
validates :street, :exterior_number, :neighborhood, :postal_code, :city, :state, presence: true
```

## UI/UX

- La sección se muestra como **acordeón colapsado por defecto** para no ocupar espacio innecesario
- Al hacer clic en el título o descripción, se expande mostrando el formulario
- Icono de chevron indica el estado (rota 180° cuando está expandido)
- Animación suave al expandir/contraer
- Estilo consistente con otras secciones de la página de configuración

## API Request

```http
PATCH /api/v1/accounts/:id
Content-Type: application/json

{
  "account_address": {
    "id": 1,  // opcional, si existe actualiza; si no, crea nuevo
    "street": "Av. Insurgentes",
    "exterior_number": "123",
    "interior_number": "4B",
    "neighborhood": "Roma Norte",
    "postal_code": "06700",
    "city": "Ciudad de México",
    "state": "CDMX",
    "email": "contacto@empresa.com",
    "phone": "+52 55 1234 5678",
    "webpage": "https://empresa.com",
    "establishment_summary": "Oficinas corporativas"
  }
}
```

## Consideraciones

1. **Seguridad**: Solo administradores pueden modificar la dirección (validado en backend)
2. **Persistencia**: Los datos se cargan automáticamente al acceder a la página
3. **Validación**: Los campos requeridos se validan en frontend y backend
4. **Internacionalización**: Soporta inglés y español
