# FAQ System

## Overview

The FAQ system provides a comprehensive solution for managing Frequently Asked Questions with multi-language support, hierarchical categories, and integration with WhatsApp AI agents.

## Features

- **Hierarchical Categories**: Tree structure with categories and subcategories (max 2 levels)
- **Multi-language Support**: FAQ items support multiple languages (Spanish and English)
- **Rich Text Answers**: WYSIWYG editor for formatting FAQ answers
- **Visibility Control**: Show/hide individual FAQs and categories
- **WhatsApp Integration**: Select which FAQ categories the AI agent can use
- **Bulk Operations**: Delete multiple FAQs at once

## Database Schema

### faq_categories

| Column | Type | Description |
|--------|------|-------------|
| id | bigint | Primary key |
| account_id | bigint | Foreign key to accounts |
| parent_id | bigint | Self-referential FK for tree structure |
| name | string | Category name |
| description | text | Optional description |
| position | integer | Sort order |
| is_visible | boolean | Visibility flag |
| created_by_id | bigint | FK to users |
| updated_by_id | bigint | FK to users |

### faq_items

| Column | Type | Description |
|--------|------|-------------|
| id | bigint | Primary key |
| account_id | bigint | Foreign key to accounts |
| faq_category_id | bigint | FK to faq_categories |
| position | integer | Sort order |
| is_visible | boolean | Visibility flag |
| translations | jsonb | Multi-language content |
| created_by_id | bigint | FK to users |
| updated_by_id | bigint | FK to users |

**Translations JSONB structure:**
```json
{
  "es": {
    "question": "Pregunta en español",
    "answer": "<p>Respuesta con formato</p>"
  },
  "en": {
    "question": "Question in English",
    "answer": "<p>Formatted answer</p>"
  }
}
```

### inbox_faq_categories

| Column | Type | Description |
|--------|------|-------------|
| id | bigint | Primary key |
| inbox_id | bigint | FK to inboxes |
| faq_category_id | bigint | FK to faq_categories |

## API Endpoints

### FAQ Categories

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/accounts/:account_id/faq_categories` | List all categories |
| GET | `/api/v1/accounts/:account_id/faq_categories/tree` | Get category tree |
| POST | `/api/v1/accounts/:account_id/faq_categories` | Create category |
| GET | `/api/v1/accounts/:account_id/faq_categories/:id` | Get category |
| PATCH | `/api/v1/accounts/:account_id/faq_categories/:id` | Update category |
| DELETE | `/api/v1/accounts/:account_id/faq_categories/:id` | Delete category |
| POST | `/api/v1/accounts/:account_id/faq_categories/:id/toggle_visibility` | Toggle visibility |
| POST | `/api/v1/accounts/:account_id/faq_categories/:id/move` | Move category position |

### FAQ Items

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/accounts/:account_id/faq_items` | List FAQs (paginated) |
| POST | `/api/v1/accounts/:account_id/faq_items` | Create FAQ |
| GET | `/api/v1/accounts/:account_id/faq_items/:id` | Get FAQ |
| PATCH | `/api/v1/accounts/:account_id/faq_items/:id` | Update FAQ |
| DELETE | `/api/v1/accounts/:account_id/faq_items/:id` | Delete FAQ |
| POST | `/api/v1/accounts/:account_id/faq_items/:id/toggle_visibility` | Toggle visibility |
| POST | `/api/v1/accounts/:account_id/faq_items/bulk_delete` | Bulk delete FAQs |

### Inbox FAQ Categories

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/accounts/:account_id/inboxes/:inbox_id/faq_categories` | Get inbox FAQ categories |
| POST | `/api/v1/accounts/:account_id/inboxes/:inbox_id/faq_categories` | Sync categories |

## Frontend Components

### Pages

- `FaqPage.vue` - Main FAQ management page in Knowledge Base section

### Components (in components-next/KnowledgeBase/Pages/FaqPage/)

- `FaqTreeView.vue` - Category tree sidebar
- `FaqTreeNode.vue` - Recursive tree node component
- `FaqItemsTable.vue` - FAQ items list with pagination
- `FaqCategoryModal.vue` - Create/edit category modal
- `FaqItemDrawer.vue` - Create/edit FAQ drawer with language tabs
- `FaqEmptyState.vue` - Empty state component
- `FaqConfirmDeleteDialog.vue` - Delete confirmation dialog

### Inbox Settings

- `FaqCategorySelector.vue` - Category selector for Bot Configuration

## Store Modules

### faqCategories

**State:**
- `records`: Object map of category records
- `tree`: Array of tree structure
- `uiFlags`: Loading states

**Actions:**
- `fetch` - Fetch all categories
- `fetchTree` - Fetch tree structure
- `create` - Create category
- `update` - Update category
- `delete` - Delete category
- `toggleVisibility` - Toggle category visibility
- `move` - Reorder category

### faqItems

**State:**
- `records`: Object map of FAQ records
- `meta`: Pagination metadata
- `uiFlags`: Loading states

**Actions:**
- `fetch` - Fetch FAQs with pagination
- `create` - Create FAQ
- `update` - Update FAQ
- `delete` - Delete FAQ
- `toggleVisibility` - Toggle FAQ visibility
- `bulkDelete` - Delete multiple FAQs

## Usage

### Creating a Category

1. Navigate to Knowledge Base > FAQs
2. Click "New Category" button
3. Enter category name and optional description
4. Select parent category if creating a subcategory
5. Click "Save"

### Creating a FAQ

1. Select a category from the tree (or stay on "All FAQs")
2. Click "New FAQ" button
3. Fill in the question and answer for each language
4. Select the category
5. Click "Save"

### Configuring WhatsApp AI Agent

1. Go to Settings > Inboxes > [Your WhatsApp Inbox]
2. Click on "AI Agent Configuration" tab
3. In the "FAQ Categories" section, check the categories you want the AI to use
4. Click "Save Configuration"

## Files Created

### Backend (Rails)

```
db/migrate/
├── 20251222161241_create_faq_categories.rb
├── 20251222161242_create_faq_items.rb
└── 20251222161243_create_inbox_faq_categories.rb

app/models/
├── faq_category.rb
├── faq_item.rb
└── inbox_faq_category.rb

app/controllers/api/v1/accounts/
├── faq_categories_controller.rb
├── faq_items_controller.rb
└── inbox_faq_categories_controller.rb

app/policies/
├── faq_category_policy.rb
└── faq_item_policy.rb

app/views/api/v1/accounts/faq_categories/
├── index.json.jbuilder
├── show.json.jbuilder
├── tree.json.jbuilder
└── _category.json.jbuilder

app/views/api/v1/accounts/faq_items/
├── index.json.jbuilder
├── show.json.jbuilder
└── _item.json.jbuilder

app/views/api/v1/accounts/inbox_faq_categories/
└── index.json.jbuilder
```

### Frontend (Vue 3)

```
app/javascript/dashboard/api/
├── faqCategories.js
├── faqItems.js
└── inboxFaqCategories.js

app/javascript/dashboard/store/modules/
├── faqCategories.js
└── faqItems.js

app/javascript/dashboard/routes/dashboard/knowledge-base/pages/
└── FaqPage.vue

app/javascript/dashboard/components-next/KnowledgeBase/Pages/FaqPage/
├── FaqTreeView.vue
├── FaqTreeNode.vue
├── FaqItemsTable.vue
├── FaqCategoryModal.vue
├── FaqItemDrawer.vue
├── FaqEmptyState.vue
└── FaqConfirmDeleteDialog.vue

app/javascript/dashboard/routes/dashboard/settings/inbox/components/
└── FaqCategorySelector.vue
```

### Modified Files

```
config/routes.rb                           # Added FAQ routes
app/models/account.rb                      # Added has_many associations
app/models/inbox.rb                        # Added has_many associations
app/javascript/dashboard/store/index.js    # Registered FAQ stores
app/javascript/dashboard/store/mutation-types.js  # Added FAQ mutation types
app/javascript/dashboard/routes/dashboard/knowledge-base/knowledge-base.routes.js
app/javascript/dashboard/components-next/sidebar/Sidebar.vue
app/javascript/dashboard/i18n/locale/en/knowledgeBase.json
app/javascript/dashboard/i18n/locale/en/settings.json
app/javascript/dashboard/i18n/locale/en/inboxMgmt.json
app/javascript/dashboard/routes/dashboard/settings/inbox/components/BotConfiguration.vue
```

## Permissions

All FAQ operations require **administrator** role. This is enforced through Pundit policies.

## Notes

- Maximum category depth is 2 levels (category -> subcategory)
- Primary question/answer is stored using the first available translation
- When a category is deleted, all its subcategories and FAQ items are also deleted
- FAQ visibility affects whether the AI agent can use them for responses
