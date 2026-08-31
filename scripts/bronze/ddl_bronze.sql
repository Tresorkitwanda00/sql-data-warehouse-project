/*
===============================================================================
Script DDL : Création des tables de la couche Bronze
===============================================================================

Objectif du script :
    Ce script permet de créer les tables du schéma 'bronze' du Data Warehouse.

    Avant de créer chaque table, le script vérifie si celle-ci existe déjà.
    Si elle existe, elle est supprimée afin de pouvoir être recréée avec
    la nouvelle structure définie dans ce script.

Pourquoi cette approche ?
    La couche Bronze est destinée à recevoir les données provenant des
    différentes sources (CRM et ERP), généralement dans un état proche
    des données originales.

    Ce script permet donc de réinitialiser facilement la structure des
    tables Bronze pendant la phase de développement du Data Warehouse.

Attention :
    DROP TABLE supprime la table et toutes les données qu'elle contient.
    Ce script est donc principalement destiné au développement et aux tests.

===============================================================================
*/


/*
===============================================================================
1. TABLE : bronze.crm_cust_info
===============================================================================

Cette table contient les informations de base sur les clients provenant
du système CRM (Customer Relationship Management).

Avant de créer la table, nous vérifions si elle existe déjà.
===============================================================================
*/

-- Vérifier si la table bronze.crm_cust_info existe.
-- OBJECT_ID retourne l'identifiant de l'objet SQL Server.
-- Le paramètre 'U' indique que nous recherchons une table utilisateur.
IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NOT NULL

    -- Si la table existe, elle est supprimée.
    DROP TABLE bronze.crm_cust_info;
GO


-- Création de la table contenant les informations des clients CRM.
CREATE TABLE bronze.crm_cust_info (

    -- Identifiant unique du client provenant du système source.
    cst_id INT,

    -- Clé ou code du client provenant du système source.
    cst_key NVARCHAR(50),

    -- Prénom du client.
    cst_firstname NVARCHAR(50),

    -- Nom de famille du client.
    cst_lastname NVARCHAR(50),

    -- Situation matrimoniale du client.
    cst_marital_status NVARCHAR(50),

    -- Genre du client.
    cst_gndr NVARCHAR(50),

    -- Date de création du client dans le système CRM.
    cst_create_date DATE
);
GO


/*
===============================================================================
2. TABLE : bronze.crm_prd_info
===============================================================================

Cette table contient les informations relatives aux produits provenant
du système CRM.
===============================================================================
*/

-- Vérifier si la table bronze.crm_prd_info existe déjà.
IF OBJECT_ID('bronze.crm_prd_info', 'U') IS NOT NULL

    -- Supprimer la table si elle existe.
    DROP TABLE bronze.crm_prd_info;
GO


-- Création de la table des produits CRM.
CREATE TABLE bronze.crm_prd_info (

    -- Identifiant du produit.
    prd_id INT,

    -- Clé ou code du produit.
    prd_key NVARCHAR(50),

    -- Nom du produit.
    prd_nm NVARCHAR(50),

    -- Coût du produit.
    prd_cost INT,

    -- Ligne ou catégorie générale du produit.
    prd_line NVARCHAR(50),

    -- Date de début de validité du produit.
    prd_start_dt DATETIME,

    -- Date de fin de validité du produit.
    prd_end_dt DATETIME
);
GO


/*
===============================================================================
3. TABLE : bronze.crm_sales_details
===============================================================================

Cette table contient les informations détaillées relatives aux ventes
provenant du système CRM.

Elle permet notamment de conserver les informations sur les commandes,
les produits vendus, les clients, les dates et les montants.
===============================================================================
*/

-- Vérifier si la table bronze.crm_sales_details existe déjà.
IF OBJECT_ID('bronze.crm_sales_details', 'U') IS NOT NULL

    -- Supprimer la table si elle existe.
    DROP TABLE bronze.crm_sales_details;
GO


-- Création de la table contenant les détails des ventes.
CREATE TABLE bronze.crm_sales_details (

    -- Numéro de la commande.
    sls_ord_num NVARCHAR(50),

    -- Clé du produit vendu.
    sls_prd_key NVARCHAR(50),

    -- Identifiant du client ayant effectué la commande.
    sls_cust_id INT,

    -- Date de commande.
    -- Elle est actuellement stockée sous forme d'entier dans la source.
    sls_order_dt INT,

    -- Date d'expédition.
    -- Elle est actuellement stockée sous forme d'entier dans la source.
    sls_ship_dt INT,

    -- Date prévue de livraison.
    -- Elle est actuellement stockée sous forme d'entier dans la source.
    sls_due_dt INT,

    -- Montant total de la vente.
    sls_sales INT,

    -- Quantité de produits vendus.
    sls_quantity INT,

    -- Prix du produit.
    sls_price INT
);
GO


/*
===============================================================================
4. TABLE : bronze.erp_loc_a101
===============================================================================

Cette table contient les informations géographiques provenant du système ERP.

Elle permet notamment d'associer un identifiant client à un pays.
===============================================================================
*/

-- Vérifier si la table bronze.erp_loc_a101 existe déjà.
IF OBJECT_ID('bronze.erp_loc_a101', 'U') IS NOT NULL

    -- Supprimer la table si elle existe.
    DROP TABLE bronze.erp_loc_a101;
GO


-- Création de la table des informations géographiques ERP.
CREATE TABLE bronze.erp_loc_a101 (

    -- Identifiant du client provenant du système ERP.
    cid NVARCHAR(50),

    -- Pays associé au client.
    cntry NVARCHAR(50)
);
GO


/*
===============================================================================
5. TABLE : bronze.erp_cust_az12
===============================================================================

Cette table contient des informations complémentaires sur les clients
provenant du système ERP.

Elle contient notamment la date de naissance et le genre du client.
===============================================================================
*/

-- Vérifier si la table bronze.erp_cust_az12 existe déjà.
IF OBJECT_ID('bronze.erp_cust_az12', 'U') IS NOT NULL

    -- Supprimer la table si elle existe.
    DROP TABLE bronze.erp_cust_az12;
GO


-- Création de la table des informations complémentaires des clients ERP.
CREATE TABLE bronze.erp_cust_az12 (

    -- Identifiant du client provenant de l'ERP.
    cid NVARCHAR(50),

    -- Date de naissance du client.
    bdate DATE,

    -- Genre du client.
    gen NVARCHAR(50)
);
GO


/*
===============================================================================
6. TABLE : bronze.erp_px_cat_g1v2
===============================================================================

Cette table contient les informations relatives aux catégories et
sous-catégories des produits provenant du système ERP.

Elle contient également une information concernant la maintenance
du produit ou de la catégorie.
===============================================================================
*/

-- Vérifier si la table bronze.erp_px_cat_g1v2 existe déjà.
IF OBJECT_ID('bronze.erp_px_cat_g1v2', 'U') IS NOT NULL

    -- Supprimer la table si elle existe.
    DROP TABLE bronze.erp_px_cat_g1v2;
GO


-- Création de la table des catégories de produits ERP.
CREATE TABLE bronze.erp_px_cat_g1v2 (

    -- Identifiant ou clé du produit.
    id NVARCHAR(50),

    -- Catégorie principale du produit.
    cat NVARCHAR(50),

    -- Sous-catégorie du produit.
    subcat NVARCHAR(50),

    -- Information relative à la maintenance.
    maintenance NVARCHAR(50)
);
GO
