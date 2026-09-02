

# 🏆 Data Warehouse - SQL Server

## Couche : Gold

### Objet : `gold.fact_sales`

---

## 🎯 Objectif

Construire la **table de faits des ventes** à partir des données nettoyées présentes dans la couche **Silver**.

Cette table représente le **CENTRE** du modèle en étoile (*Star Schema*). Elle permet de relier les transactions commerciales :

* aux produits (`gold.dim_products`)
* aux clients (`gold.dim_customers`)
* aux différentes dates de la transaction
* aux mesures commerciales (montants, quantités, prix)

---

## 📐 Architecture du Modèle

```text
                        ┌─────────────────────────┐
                        │    gold.dim_products    │
                        ├─────────────────────────┤
                        │ product_key             │
                        │ product_id              │
                        │ product_number          │
                        │ product_name            │
                        │ category                │
                        │ subcategory             │
                        └────────────┬────────────┘
                                     │
                                     │ product_key
                                     ▼
                        ┌─────────────────────────┐
                        │     gold.fact_sales     │
                        ├─────────────────────────┤
                        │ order_number            │
                        │ product_key             │
                        │ customer_key            │
                        │ order_date              │
                        │ shipping_date           │
                        │ due_date                │
                        │ sales_amount            │
                        │ quantity                │
                        │ price                   │
                        └────────────┬────────────┘
                                     │
                                     │ customer_key
                                     ▼
                        ┌─────────────────────────┐
                        │   gold.dim_customers    │
                        ├─────────────────────────┤
                        │ customer_key            │
                        │ customer_id             │
                        │ customer_number         │
                        │ first_name              │
                        │ last_name               │
                        │ country                 │
                        │ gender                  │
                        └─────────────────────────┘

```

---

## 🔍 Granularité (Grain)

La granularité de cette table est : **UNE LIGNE DE VENTE / LIGNE DE TRANSACTION**.

Une même commande peut donc contenir plusieurs lignes.

> **Exemple pour la commande `SO54496` :**
> * Produit A → quantité 2
> * Produit B → quantité 1
> * Produit C → quantité 4
> 
> 
> *Générera 3 lignes distinctes dans `gold.fact_sales`.*

---

## 🗂️ Sources de Données

* **Source principale :** `silver.crm_sales_details`
* **Dimensions :**
* `gold.dim_products`
* `gold.dim_customers`



---

## 🛠️ Principes de Construction

1. Récupérer le numéro de commande.
2. Récupérer la clé substitut du produit (*surrogate key*).
3. Récupérer la clé substitut du client (*surrogate key*).
4. Récupérer les différentes dates associées (commande, expédition, échéance).
5. Récupérer les mesures commerciales.
6. Ajouter la date de chargement ETL.

---

## 💻 Script SQL de Création

```sql
-- ============================================================================
-- CRÉATION DE LA TABLE DE FAITS DES VENTES
-- ============================================================================

CREATE VIEW gold.fact_sales AS

SELECT
    -- ------------------------------------------------------------------------
    -- 1. IDENTIFICATION DE LA TRANSACTION
    -- ------------------------------------------------------------------------
    /*
        Numéro de commande provenant du CRM.
        Cette colonne permet d'identifier la commande commerciale
        à laquelle appartient la ligne de vente.
    */
    sd.sls_ord_num AS order_number,

    -- ------------------------------------------------------------------------
    -- 2. CLÉS DES DIMENSIONS
    -- ------------------------------------------------------------------------
    /*
        Clé substitut du produit provenant de gold.dim_products.
        Permet de relier la vente au produit correspondant.
    */
    pr.product_key AS product_key,

    /*
        Clé substitut du client provenant de gold.dim_customers.
        Permet de relier la vente au client correspondant.
    */
    cu.customer_key AS customer_key,

    -- ------------------------------------------------------------------------
    -- 3. DATES DE LA TRANSACTION
    -- ------------------------------------------------------------------------
    /* Date à laquelle la commande a été passée. */
    sd.sls_order_dt AS order_date,

    /* Date à laquelle la commande a été expédiée. */
    sd.sls_ship_dt AS shipping_date,

    /* Date d'échéance ou date prévue pour la commande. */
    sd.sls_due_dt AS due_date,

    -- ------------------------------------------------------------------------
    -- 4. MESURES COMMERCIALES
    -- ------------------------------------------------------------------------
    /*
        Montant total de la vente correspondant à la ligne de transaction.
        Utilisé pour calculer le chiffre d'affaires, ventes par produit/client/période/catégorie.
    */
    sd.sls_sales AS sales_amount,

    /* Quantité de produits vendus pour cette ligne (ex: 5 = 5 unités). */
    sd.sls_quantity AS quantity,

    /* Prix unitaire du produit vendu (ex: 25 = 25€ / unité). */
    sd.sls_price AS price,

    -- ------------------------------------------------------------------------
    -- 5. MÉTADONNÉES DU DATA WAREHOUSE
    -- ------------------------------------------------------------------------
    /*
        Date et heure de chargement de l'enregistrement dans le Data Warehouse.
    */
    sd.dwh_create_date AS load_date

-- ============================================================================
-- SOURCE PRINCIPALE
-- ============================================================================
FROM silver.crm_sales_details AS sd

-- ============================================================================
-- JOINTURE AVEC LA DIMENSION PRODUITS
-- ============================================================================
/*
    OBJECTIF : Associer chaque ligne de vente au produit correspondant.
    RELATION : silver.crm_sales_details.sls_prd_key = gold.dim_products.product_number

    Pourquoi LEFT JOIN ?
    Conserver la transaction même si le produit est introuvable dans la dimension.
    Dans ce cas : product_key = NULL.
*/
LEFT JOIN gold.dim_products AS pr
    ON sd.sls_prd_key = pr.product_number

-- ============================================================================
-- JOINTURE AVEC LA DIMENSION CLIENTS
-- ============================================================================
/*
    OBJECTIF : Associer chaque vente au client qui a effectué la commande.
    RELATION : silver.crm_sales_details.sls_cust_id = gold.dim_customers.customer_id

    Récupère cu.customer_key pour la stocker dans fact_sales.
*/
LEFT JOIN gold.dim_customers AS cu
    ON sd.sls_cust_id = cu.customer_id;

```
