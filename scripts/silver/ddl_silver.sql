/*
===============================================================================
Script DDL : Création des tables de la couche Silver
===============================================================================

OBJECTIF DU SCRIPT :
    Ce script permet de créer les tables du schéma 'silver' du Data Warehouse.

    Pour chaque table :
        1. Vérifier si la table existe déjà.
        2. Supprimer la table si elle existe.
        3. Recréer la table avec la structure souhaitée.

RÔLE DE LA COUCHE SILVER :
    La couche Silver contient des données qui ont été nettoyées,
    standardisées et transformées à partir des données de la couche Bronze.

    Exemple :

        BRONZE
        Données proches de la source
              ↓
        Nettoyage / Transformation
              ↓
        SILVER
        Données propres et standardisées

PRINCIPALES TRANSFORMATIONS ATTENDUES EN SILVER :
    - Nettoyage des valeurs incorrectes.
    - Suppression ou gestion des doublons.
    - Standardisation des textes.
    - Conversion des types de données.
    - Conversion des dates stockées sous forme numérique.
    - Harmonisation des valeurs provenant de plusieurs sources.
    - Préparation des données pour la couche Gold.

COLONNE TECHNIQUE :
    La colonne 'dwh_create_date' permet d'enregistrer la date et l'heure
    auxquelles une ligne a été chargée dans le Data Warehouse.

===============================================================================
*/


/*
===============================================================================
1. TABLE : silver.crm_cust_info
===============================================================================

Cette table contient les informations clients provenant du système CRM.

Contrairement à la couche Bronze, cette table Silver est destinée à recevoir
des données nettoyées et standardisées.
===============================================================================
*/

-- Vérifier si la table Silver des clients CRM existe déjà.
IF OBJECT_ID('silver.crm_cust_info', 'U') IS NOT NULL

    -- Si la table existe, la supprimer avant de la recréer.
    DROP TABLE silver.crm_cust_info;
GO


-- Création de la table Silver contenant les informations clients.
CREATE TABLE silver.crm_cust_info (

    -- Identifiant du client.
    cst_id INT,

    -- Clé métier du client provenant du système source.
    cst_key NVARCHAR(50),

    -- Prénom du client.
    cst_firstname NVARCHAR(50),

    -- Nom de famille du client.
    cst_lastname NVARCHAR(50),

    -- Situation matrimoniale du client.
    cst_marital_status NVARCHAR(50),

    -- Genre du client.
    cst_gndr NVARCHAR(50),

    -- Date de création du client.
    cst_create_date DATE,

    -- Date et heure auxquelles la donnée a été chargée
    -- dans le Data Warehouse.
    --
    -- DATETIME2 permet de stocker la date et l'heure avec
    -- une précision supérieure à DATETIME.
    --
    -- DEFAULT GETDATE() signifie que SQL Server remplit
    -- automatiquement cette colonne si aucune valeur n'est fournie.
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO


/*
===============================================================================
2. TABLE : silver.crm_prd_info
===============================================================================

Cette table contient les informations sur les produits provenant du CRM.

La structure Silver introduit notamment 'cat_id', qui permettra d'identifier
la catégorie du produit et de faciliter les relations avec les informations
provenant de l'ERP.
===============================================================================
*/

-- Vérifier si la table Silver des produits CRM existe.
IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL

    -- Supprimer la table si elle existe.
    DROP TABLE silver.crm_prd_info;
GO


-- Création de la table Silver des produits.
CREATE TABLE silver.crm_prd_info (

    -- Identifiant du produit.
    prd_id INT,

    -- Identifiant de la catégorie du produit.
    --
    -- Cette colonne peut être dérivée de la clé du produit
    -- lors du processus de transformation Bronze -> Silver.
    --
    -- Elle permettra notamment de faire le lien avec les données
    -- de catégories provenant du système ERP.
    cat_id NVARCHAR(50),

    -- Clé métier du produit provenant du système source.
    prd_key NVARCHAR(50),

    -- Nom du produit.
    prd_nm NVARCHAR(50),

    -- Coût du produit.
    prd_cost INT,

    -- Ligne ou type de produit.
    prd_line NVARCHAR(50),

    -- Date de début de validité du produit.
    --
    -- Dans Bronze, cette information était stockée en DATETIME.
    -- Elle est ici standardisée en DATE car l'heure n'est pas
    -- nécessaire pour l'analyse de cette information.
    prd_start_dt DATE,

    -- Date de fin de validité du produit.
    prd_end_dt DATE,

    -- Date et heure de chargement de la ligne dans le Data Warehouse.
    --
    -- La valeur est automatiquement générée par SQL Server.
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO


/*
===============================================================================
3. TABLE : silver.crm_sales_details
===============================================================================

Cette table contient les détails des ventes provenant du système CRM.

Dans la couche Bronze, les dates de commande, d'expédition et d'échéance
étaient stockées sous forme d'entiers.

Dans la couche Silver, elles sont converties en véritables valeurs DATE.
===============================================================================
*/

-- Vérifier si la table Silver des ventes existe déjà.
IF OBJECT_ID('silver.crm_sales_details', 'U') IS NOT NULL

    -- Supprimer la table si elle existe.
    DROP TABLE silver.crm_sales_details;
GO


-- Création de la table Silver contenant les détails des ventes.
CREATE TABLE silver.crm_sales_details (

    -- Numéro de la commande.
    sls_ord_num NVARCHAR(50),

    -- Clé du produit vendu.
    sls_prd_key NVARCHAR(50),

    -- Identifiant du client ayant effectué la commande.
    sls_cust_id INT,

    -- Date de la commande.
    --
    -- Dans Bronze, cette colonne était de type INT.
    -- Elle sera transformée en DATE pendant le chargement Silver.
    sls_order_dt DATE,

    -- Date d'expédition.
    --
    -- Conversion de INT vers DATE lors du processus ETL.
    sls_ship_dt DATE,

    -- Date prévue de livraison.
    --
    -- Conversion de INT vers DATE lors du processus ETL.
    sls_due_dt DATE,

    -- Montant total de la vente.
    sls_sales INT,

    -- Quantité de produits vendus.
    sls_quantity INT,

    -- Prix du produit.
    sls_price INT,

    -- Date et heure du chargement de la donnée dans le Data Warehouse.
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO


/*
===============================================================================
4. TABLE : silver.erp_loc_a101
===============================================================================

Cette table contient les informations géographiques provenant de l'ERP.

Elle permet notamment d'associer un identifiant client à un pays.
===============================================================================
*/

-- Vérifier si la table Silver des localisations ERP existe déjà.
IF OBJECT_ID('silver.erp_loc_a101', 'U') IS NOT NULL

    -- Supprimer la table si elle existe.
    DROP TABLE silver.erp_loc_a101;
GO


-- Création de la table Silver des informations géographiques.
CREATE TABLE silver.erp_loc_a101 (

    -- Identifiant du client provenant de l'ERP.
    cid NVARCHAR(50),

    -- Pays associé au client.
    --
    -- Cette valeur pourra être nettoyée et standardisée
    -- pendant le processus Bronze -> Silver.
    cntry NVARCHAR(50),

    -- Date et heure du chargement de la donnée dans le Data Warehouse.
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO


/*
===============================================================================
5. TABLE : silver.erp_cust_az12
===============================================================================

Cette table contient des informations complémentaires sur les clients
provenant du système ERP.

Elle contient notamment la date de naissance et le genre du client.
===============================================================================
*/

-- Vérifier si la table Silver des clients ERP existe déjà.
IF OBJECT_ID('silver.erp_cust_az12', 'U') IS NOT NULL

    -- Supprimer la table si elle existe.
    DROP TABLE silver.erp_cust_az12;
GO


-- Création de la table Silver des informations clients ERP.
CREATE TABLE silver.erp_cust_az12 (

    -- Identifiant du client provenant de l'ERP.
    cid NVARCHAR(50),

    -- Date de naissance du client.
    bdate DATE,

    -- Genre du client.
    gen NVARCHAR(50),

    -- Date et heure de chargement dans le Data Warehouse.
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO


/*
===============================================================================
6. TABLE : silver.erp_px_cat_g1v2
===============================================================================

Cette table contient les informations relatives aux catégories et
sous-catégories des produits provenant du système ERP.

Ces informations pourront être utilisées plus tard pour construire
les dimensions de la couche Gold.
===============================================================================
*/

-- Vérifier si la table Silver des catégories produits existe déjà.
IF OBJECT_ID('silver.erp_px_cat_g1v2', 'U') IS NOT NULL

    -- Supprimer la table si elle existe.
    DROP TABLE silver.erp_px_cat_g1v2;
GO


-- Création de la table Silver des catégories de produits.
CREATE TABLE silver.erp_px_cat_g1v2 (

    -- Identifiant du produit ou de la catégorie provenant de l'ERP.
    id NVARCHAR(50),

    -- Catégorie principale du produit.
    cat NVARCHAR(50),

    -- Sous-catégorie du produit.
    subcat NVARCHAR(50),

    -- Information relative à la maintenance.
    maintenance NVARCHAR(50),

    -- Date et heure du chargement de la donnée dans le Data Warehouse.
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO
