/*
===============================================================================
PROJET : DATA WAREHOUSE - SQL SERVER
COUCHE : GOLD
SCRIPT : CONSTRUCTION DE LA COUCHE ANALYTIQUE EN ÉTOILE (STAR SCHEMA)
===============================================================================
Ce fichier contient les scripts de création pour :
    1. gold.dim_customers (Dimension Clients)
    2. gold.dim_products  (Dimension Produits)
    3. gold.fact_sales     (Table de faits des Ventes)
===============================================================================
*/


-- ============================================================================
-- 1. CRÉATION DE LA DIMENSION CLIENTS
-- ============================================================================
/*
===============================================================================
REQUÊTE : Création de la dimension clients
===============================================================================
OBJECTIF :
    Cette requête consolide les informations clients provenant de plusieurs
    systèmes sources afin de construire la dimension GOLD des clients.
    La dimension finale permettra notamment de :
        - Identifier chaque client de manière unique dans le Data Warehouse.
        - Centraliser les informations personnelles du client.
        - Enrichir les données CRM avec les informations provenant de l'ERP.
        - Fournir une table prête à être utilisée pour les analyses BI.

SOURCES UTILISÉES :
    1. silver.crm_cust_info       → Source principale (Identifiant, Clé, Nom, Prénom, Situation, Genre, Date)
    2. silver.erp_cust_az12       → Source complémentaire ERP (Date de naissance, Genre)
    3. silver.erp_loc_a101       → Source complémentaire ERP (Pays)

LOGIQUE DE CONSOLIDATION :
    CRM (cst_key) ──► ERP Customer (cid)  ──► Date de naissance, Genre
    CRM (cst_key) ──► ERP Location (cid)  ──► Pays

RÈGLE DE PRIORITÉ POUR LE GENRE :
    1. Si le genre CRM != 'n/a'  → utiliser le genre du CRM.
    2. Si le genre CRM = 'n/a'   → utiliser le genre de l'ERP (ca.gen).
    3. Si NULL                   → retourner 'n/a'.

CLÉ SUBSTITUT :
    ROW_NUMBER() génère customer_key (Clé technique indépendante).
===============================================================================
*/

IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS
SELECT
    -- ------------------------------------------------------------------------
    -- CLÉ SURROGATE / CLÉ TECHNIQUE DU DATA WAREHOUSE
    -- ------------------------------------------------------------------------
    ROW_NUMBER() OVER (
        ORDER BY ci.cst_id
    ) AS customer_key,

    -- ------------------------------------------------------------------------
    -- IDENTIFICATION DU CLIENT
    -- ------------------------------------------------------------------------
    ci.cst_id AS customer_id,
    ci.cst_key AS customer_number,

    -- ------------------------------------------------------------------------
    -- INFORMATIONS PERSONNELLES
    -- ------------------------------------------------------------------------
    ci.cst_firstname AS first_name,
    ci.cst_lastname AS last_name,
    ci.cst_marital_status AS marital_status,
    ci.cst_create_date AS customer_create_date,

    -- ------------------------------------------------------------------------
    -- INFORMATIONS COMPLÉMENTAIRES PROVENANT DE L'ERP
    -- ------------------------------------------------------------------------
    ca.bdate AS birth_date,

    -- ------------------------------------------------------------------------
    -- CONSOLIDATION DU GENRE
    -- ------------------------------------------------------------------------
    CASE
        WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr
        ELSE COALESCE(ca.gen, 'n/a')
    END AS gender,

    -- ------------------------------------------------------------------------
    -- LOCALISATION DU CLIENT
    -- ------------------------------------------------------------------------
    la.cntry AS country

-- ============================================================================
-- SOURCES ET JOINTURES
-- ============================================================================
FROM silver.crm_cust_info AS ci
LEFT JOIN silver.erp_cust_az12 AS ca
    ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 AS la
    ON ci.cst_key = la.cid;
GO

-- Vérification des données de la dimension clients
SELECT * FROM gold.dim_customers;
GO


-- ============================================================================
-- 2. CRÉATION DE LA DIMENSION PRODUITS
-- ============================================================================
/*
===============================================================================
REQUÊTE : Création de la dimension Produits
===============================================================================
OBJECTIF :
    Cette vue consolide les informations produits provenant de la couche Silver
    afin de construire la dimension "dim_products" dans la couche Gold.
    
SOURCES UTILISÉES :
    1. silver.crm_prd_info       → Source principale produits
    2. silver.erp_px_cat_g1v2       → Classification ERP (Catégorie, Sous-catégorie, Maintenance)

LOGIQUE DE CONSOLIDATION :
    crm_prd_info (cat_id) ──► erp_px_cat_g1v2 (id)

RÈGLE SUR LES PRODUITS ACTIFS :
    Seuls les produits dont prd_end_dt IS NULL sont conservés.

CLÉ SUBSTITUT :
    ROW_NUMBER() génère product_key.
===============================================================================
*/

IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS
SELECT
    -- ------------------------------------------------------------------------
    -- 1. CLÉ TECHNIQUE DU DATA WAREHOUSE
    -- ------------------------------------------------------------------------
    ROW_NUMBER() OVER (
        ORDER BY
            pn.prd_start_dt,
            pn.prd_key
    ) AS product_key,

    -- ------------------------------------------------------------------------
    -- 2. IDENTIFICATION DU PRODUIT
    -- ------------------------------------------------------------------------
    pn.prd_id AS product_id,
    pn.prd_key AS product_number,

    -- ------------------------------------------------------------------------
    -- 3. INFORMATIONS DESCRIPTIVES DU PRODUIT
    -- ------------------------------------------------------------------------
    pn.prd_nm AS product_name,
    pn.prd_line AS product_line,

    -- ------------------------------------------------------------------------
    -- 4. CLASSIFICATION DU PRODUIT
    -- ------------------------------------------------------------------------
    pn.cat_id AS category_id,
    pc.cat AS category,
    pc.subcat AS subcategory,
    pc.maintenance AS maintenance,

    -- ------------------------------------------------------------------------
    -- 5. INFORMATIONS COMMERCIALES
    -- ------------------------------------------------------------------------
    pn.prd_cost AS product_cost,

    -- ------------------------------------------------------------------------
    -- 6. DATES DE VALIDITÉ DU PRODUIT
    -- ------------------------------------------------------------------------
    pn.prd_start_dt AS start_date,

    -- ------------------------------------------------------------------------
    -- 7. MÉTADONNÉES DU DATA WAREHOUSE
    -- ------------------------------------------------------------------------
    pn.dwh_create_date AS load_date

-- ============================================================================
-- SOURCES ET JOINTURES
-- ============================================================================
FROM silver.crm_prd_info AS pn
LEFT JOIN silver.erp_px_cat_g1v2 AS pc
    ON pn.cat_id = pc.id
-- Filtre uniquement sur les produits actifs
WHERE pn.prd_end_dt IS NULL;
GO

-- Vérification des données de la dimension produits
SELECT * FROM gold.dim_products;
GO


-- ============================================================================
-- 3. CRÉATION DE LA TABLE DE FAITS DES VENTES
-- ============================================================================
/*
===============================================================================
REQUÊTE : Création de la table de faits des ventes
===============================================================================
OBJECTIF :
    Cette vue consolide les transactions commerciales de la couche Silver pour
    construire la table de faits au CENTRE du modèle en étoile.

SOURCE PRINCIPALE :
    silver.crm_sales_details

DIMENSIONS UTILISÉES :
    1. gold.dim_products   → Associe la vente au produit (sls_prd_key = product_number)
    2. gold.dim_customers  → Associe la vente au client (sls_cust_id = customer_id)

GRANULARITÉ :
    Une ligne = Une ligne de transaction / ligne de commande.
===============================================================================
*/

IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fact_sales AS
SELECT
    -- ------------------------------------------------------------------------
    -- 1. IDENTIFICATION DE LA TRANSACTION
    -- ------------------------------------------------------------------------
    sd.sls_ord_num AS order_number,

    -- ------------------------------------------------------------------------
    -- 2. CLÉS DES DIMENSIONS (SURROGATE KEYS)
    -- ------------------------------------------------------------------------
    pr.product_key AS product_key,
    cu.customer_key AS customer_key,

    -- ------------------------------------------------------------------------
    -- 3. DATES DE LA TRANSACTION
    -- ------------------------------------------------------------------------
    sd.sls_order_dt AS order_date,
    sd.sls_ship_dt AS shipping_date,
    sd.sls_due_dt AS due_date,

    -- ------------------------------------------------------------------------
    -- 4. MESURES COMMERCIALES
    -- ------------------------------------------------------------------------
    sd.sls_sales AS sales_amount,
    sd.sls_quantity AS quantity,
    sd.sls_price AS unit_price,

    -- ------------------------------------------------------------------------
    -- 5. MÉTADONNÉES DU DATA WAREHOUSE
    -- ------------------------------------------------------------------------
    sd.dwh_create_date AS load_date

-- ============================================================================
-- SOURCES ET JOINTURES
-- ============================================================================
FROM silver.crm_sales_details AS sd
LEFT JOIN gold.dim_products AS pr
    ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers AS cu
    ON sd.sls_cust_id = cu.customer_id;
GO

-- Vérification des données de la table de faits
SELECT * FROM gold.fact_sales;
GO
