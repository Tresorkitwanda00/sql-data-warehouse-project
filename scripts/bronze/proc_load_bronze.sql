/*
===============================================================================
Procédure stockée : Chargement de la couche Bronze (Source -> Bronze)
===============================================================================

OBJECTIF DU SCRIPT :
    Cette procédure stockée permet de charger automatiquement les données
    provenant des fichiers CSV externes dans les tables du schéma 'bronze'.

    Le processus réalisé est le suivant :

        1. Vider les anciennes données des tables Bronze.
        2. Lire les fichiers CSV provenant des sources CRM et ERP.
        3. Charger les données des fichiers CSV dans les tables Bronze.
        4. Mesurer le temps nécessaire au chargement de chaque table.
        5. Mesurer la durée totale du processus.
        6. Afficher des messages permettant de suivre l'avancement du traitement.
        7. Capturer et afficher les informations en cas d'erreur.

STRUCTURE DU FLUX :

        Fichiers CSV CRM
              |
              v
        Tables Bronze CRM
              |
              |
        Fichiers CSV ERP
              |
              v
        Tables Bronze ERP

PARAMÈTRES :
    Aucun paramètre n'est nécessaire pour cette procédure.

UTILISATION :
    Pour exécuter la procédure :

        EXEC bronze.load_bronze;

ATTENTION :
    La commande TRUNCATE TABLE supprime toutes les données présentes
    dans les tables Bronze avant de charger les nouvelles données.

===============================================================================
*/


-- ============================================================================
-- CRÉATION OU MODIFICATION DE LA PROCÉDURE STOCKÉE
-- ============================================================================

-- CREATE OR ALTER permet :
--     - de créer la procédure si elle n'existe pas ;
--     - de la modifier si elle existe déjà.
--
-- La procédure est créée dans le schéma 'bronze'.
--
-- Son nom est : load_bronze
CREATE OR ALTER PROCEDURE bronze.load_bronze
AS
BEGIN


    -- =========================================================================
    -- DÉCLARATION DES VARIABLES DE TEMPS
    -- =========================================================================

    -- @start_time :
    --     contient l'heure de début du chargement d'une table.
    --
    -- @end_time :
    --     contient l'heure de fin du chargement d'une table.
    --
    -- @batch_start_time :
    --     contient l'heure de début du chargement global de la couche Bronze.
    --
    -- @batch_end_time :
    --     contient l'heure de fin du chargement global.
    DECLARE
        @start_time DATETIME,
        @end_time DATETIME,
        @batch_start_time DATETIME,
        @batch_end_time DATETIME;


    -- =========================================================================
    -- BLOC TRY : EXÉCUTION DU PROCESSUS DE CHARGEMENT
    -- =========================================================================

    -- BEGIN TRY permet d'exécuter le processus tout en permettant
    -- de capturer une éventuelle erreur dans le bloc BEGIN CATCH.
    BEGIN TRY


        -- Enregistrer l'heure de début du chargement global.
        -- GETDATE() retourne la date et l'heure actuelles du serveur SQL.
        SET @batch_start_time = GETDATE();


        -- Afficher un séparateur dans la console SQL Server.
        PRINT '================================================';

        -- Indiquer que le chargement de la couche Bronze commence.
        PRINT 'Loading Bronze Layer';

        -- Afficher un autre séparateur.
        PRINT '================================================';


        -- =====================================================================
        -- CHARGEMENT DES TABLES CRM
        -- =====================================================================

        -- Afficher une ligne de séparation.
        PRINT '------------------------------------------------';

        -- Indiquer que les tables provenant du CRM vont être chargées.
        PRINT 'Loading CRM Tables';

        -- Afficher une ligne de séparation.
        PRINT '------------------------------------------------';


        -- =====================================================================
        -- 1. CHARGEMENT DE bronze.crm_cust_info
        -- =====================================================================

        -- Enregistrer l'heure de début du chargement de la table.
        SET @start_time = GETDATE();


        -- Afficher le nom de la table qui va être vidée.
        PRINT '>> Truncating Table: bronze.crm_cust_info';


        -- TRUNCATE TABLE supprime toutes les données existantes
        -- dans la table avant le nouveau chargement.
        --
        -- Contrairement à DELETE, TRUNCATE est généralement plus rapide
        -- pour supprimer l'ensemble des lignes d'une table.
        TRUNCATE TABLE bronze.crm_cust_info;


        -- Indiquer que l'insertion des données va commencer.
        PRINT '>> Inserting Data Into: bronze.crm_cust_info';


        -- BULK INSERT permet de charger rapidement un grand nombre
        -- de lignes provenant d'un fichier externe dans une table SQL Server.
        BULK INSERT bronze.crm_cust_info

        -- Chemin du fichier CSV contenant les données clients CRM.
        FROM 'D:\Programme Akieni\Programme Akieni\DataScience\sql-data-warehouse-project\datasets\source_crm\cust_info.csv'

        -- Options utilisées lors de l'importation du fichier CSV.
        WITH (

            -- La première ligne du fichier contient généralement
            -- les noms des colonnes.
            -- FIRSTROW = 2 signifie donc :
            -- "Commencer l'importation à partir de la deuxième ligne".
            FIRSTROW = 2,

            -- Les différentes colonnes du fichier CSV sont séparées
            -- par une virgule.
            FIELDTERMINATOR = ',',

            -- TABLOCK demande à SQL Server d'utiliser un verrou
            -- au niveau de la table pendant l'opération de chargement.
            -- Cela peut améliorer les performances lors d'un chargement massif.
            TABLOCK
        );


        -- Enregistrer l'heure de fin du chargement de la table.
        SET @end_time = GETDATE();


        -- Calculer et afficher la durée du chargement.
        --
        -- DATEDIFF(second, ...) calcule la différence en secondes
        -- entre l'heure de début et l'heure de fin.
        --
        -- CAST(... AS NVARCHAR) convertit le résultat numérique
        -- en texte afin de pouvoir le concaténer avec PRINT.
        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';


        -- Afficher un séparateur.
        PRINT '>> -------------';


        -- =====================================================================
        -- 2. CHARGEMENT DE bronze.crm_prd_info
        -- =====================================================================

        -- Enregistrer l'heure de début du chargement.
        SET @start_time = GETDATE();


        -- Afficher la table qui va être vidée.
        PRINT '>> Truncating Table: bronze.crm_prd_info';


        -- Supprimer toutes les données précédentes.
        TRUNCATE TABLE bronze.crm_prd_info;


        -- Indiquer que le chargement va commencer.
        PRINT '>> Inserting Data Into: bronze.crm_prd_info';


        -- Charger le fichier CSV des produits dans la table Bronze.
        BULK INSERT bronze.crm_prd_info

        -- Chemin du fichier contenant les informations sur les produits.
        FROM 'D:\Programme Akieni\Programme Akieni\DataScience\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'

        WITH (

            -- Ignorer la ligne d'en-tête du fichier CSV.
            FIRSTROW = 2,

            -- Les colonnes sont séparées par des virgules.
            FIELDTERMINATOR = ',',

            -- Utiliser un verrou de table pendant le chargement.
            TABLOCK
        );


        -- Enregistrer l'heure de fin du chargement.
        SET @end_time = GETDATE();


        -- Afficher la durée du chargement.
        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';


        -- Afficher un séparateur.
        PRINT '>> -------------';


        -- =====================================================================
        -- 3. CHARGEMENT DE bronze.crm_sales_details
        -- =====================================================================

        -- Enregistrer l'heure de début du chargement.
        SET @start_time = GETDATE();


        -- Afficher la table concernée.
        PRINT '>> Truncating Table: bronze.crm_sales_details';


        -- Supprimer les anciennes données.
        TRUNCATE TABLE bronze.crm_sales_details;


        -- Indiquer que l'insertion commence.
        PRINT '>> Inserting Data Into: bronze.crm_sales_details';


        -- Charger les données du fichier CSV dans la table.
        BULK INSERT bronze.crm_sales_details

        -- Chemin du fichier contenant les détails des ventes.
        FROM 'D:\Programme Akieni\Programme Akieni\DataScience\sql-data-warehouse-project\datasets\source_crm\sales_details.csv'

        WITH (

            -- Ignorer la première ligne contenant les noms des colonnes.
            FIRSTROW = 2,

            -- Les colonnes du fichier sont séparées par une virgule.
            FIELDTERMINATOR = ',',

            -- Utiliser un verrou de table pour optimiser le chargement.
            TABLOCK
        );


        -- Enregistrer l'heure de fin.
        SET @end_time = GETDATE();


        -- Afficher la durée du chargement.
        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';


        -- Afficher un séparateur.
        PRINT '>> -------------';


        -- =====================================================================
        -- CHARGEMENT DES TABLES ERP
        -- =====================================================================

        -- Afficher une ligne de séparation.
        PRINT '------------------------------------------------';

        -- Indiquer que le chargement des tables ERP commence.
        PRINT 'Loading ERP Tables';

        -- Afficher une ligne de séparation.
        PRINT '------------------------------------------------';


        -- =====================================================================
        -- 4. CHARGEMENT DE bronze.erp_loc_a101
        -- =====================================================================

        -- Enregistrer l'heure de début.
        SET @start_time = GETDATE();


        -- Afficher la table concernée.
        PRINT '>> Truncating Table: bronze.erp_loc_a101';


        -- Supprimer les anciennes données.
        TRUNCATE TABLE bronze.erp_loc_a101;


        -- Indiquer que l'insertion commence.
        PRINT '>> Inserting Data Into: bronze.erp_loc_a101';


        -- Charger le fichier CSV contenant les informations géographiques.
        BULK INSERT bronze.erp_loc_a101

        -- Chemin du fichier source ERP.
        FROM 'D:\Programme Akieni\Programme Akieni\DataScience\sql-data-warehouse-project\datasets\source_erp\loc_a101.csv'

        WITH (

            -- Ignorer l'en-tête du fichier CSV.
            FIRSTROW = 2,

            -- Les colonnes sont séparées par des virgules.
            FIELDTERMINATOR = ',',

            -- Optimisation du chargement grâce au verrou de table.
            TABLOCK
        );


        -- Enregistrer l'heure de fin.
        SET @end_time = GETDATE();


        -- Afficher la durée du chargement.
        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';


        -- Afficher un séparateur.
        PRINT '>> -------------';


        -- =====================================================================
        -- 5. CHARGEMENT DE bronze.erp_cust_az12
        -- =====================================================================

        -- Enregistrer l'heure de début.
        SET @start_time = GETDATE();


        -- Afficher la table concernée.
        PRINT '>> Truncating Table: bronze.erp_cust_az12';


        -- Supprimer les anciennes données.
        TRUNCATE TABLE bronze.erp_cust_az12;


        -- Indiquer que l'insertion commence.
        PRINT '>> Inserting Data Into: bronze.erp_cust_az12';


        -- Charger les données du fichier CSV dans la table Bronze.
        BULK INSERT bronze.erp_cust_az12

        -- Chemin du fichier contenant les informations clients ERP.
        FROM 'D:\Programme Akieni\Programme Akieni\DataScience\sql-data-warehouse-project\datasets\source_erp\cust_az12.csv'

        WITH (

            -- Ignorer la première ligne du fichier.
            FIRSTROW = 2,

            -- Séparateur utilisé dans le fichier CSV.
            FIELDTERMINATOR = ',',

            -- Utiliser un verrou de table.
            TABLOCK
        );


        -- Enregistrer l'heure de fin.
        SET @end_time = GETDATE();


        -- Afficher la durée du chargement.
        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';


        -- Afficher un séparateur.
        PRINT '>> -------------';


        -- =====================================================================
        -- 6. CHARGEMENT DE bronze.erp_px_cat_g1v2
        -- =====================================================================

        -- Enregistrer l'heure de début.
        SET @start_time = GETDATE();


        -- Afficher la table concernée.
        PRINT '>> Truncating Table: bronze.erp_px_cat_g1v2';


        -- Supprimer les anciennes données.
        TRUNCATE TABLE bronze.erp_px_cat_g1v2;


        -- Indiquer que l'insertion commence.
        PRINT '>> Inserting Data Into: bronze.erp_px_cat_g1v2';


        -- Charger le fichier CSV des catégories et sous-catégories.
        BULK INSERT bronze.erp_px_cat_g1v2

        -- Chemin du fichier source ERP.
        FROM 'D:\Programme Akieni\Programme Akieni\DataScience\sql-data-warehouse-project\datasets\source_erp\px_cat_g1v2.csv'

        WITH (

            -- Ignorer la première ligne qui contient les noms des colonnes.
            FIRSTROW = 2,

            -- Les colonnes sont séparées par des virgules.
            FIELDTERMINATOR = ',',

            -- Utiliser un verrou de table pendant le chargement.
            TABLOCK
        );


        -- Enregistrer l'heure de fin.
        SET @end_time = GETDATE();


        -- Afficher la durée du chargement.
        PRINT '>> Load Duration: '
            + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';


        -- Afficher un séparateur.
        PRINT '>> -------------';


        -- =====================================================================
        -- FIN DU CHARGEMENT GLOBAL
        -- =====================================================================

        -- Enregistrer l'heure de fin du chargement complet de la couche Bronze.
        SET @batch_end_time = GETDATE();


        -- Afficher un séparateur.
        PRINT '==========================================';


        -- Indiquer que le chargement est terminé.
        PRINT 'Loading Bronze Layer is Completed';


        -- Calculer et afficher la durée totale du processus.
        --
        -- @batch_start_time = début du processus complet
        -- @batch_end_time   = fin du processus complet
        --
        -- DATEDIFF calcule la différence en secondes.
        PRINT '   - Total Load Duration: '
            + CAST(
                DATEDIFF(
                    SECOND,
                    @batch_start_time,
                    @batch_end_time
                ) AS NVARCHAR
            )
            + ' seconds';


        -- Afficher un dernier séparateur.
        PRINT '==========================================';


    -- =========================================================================
    -- GESTION DES ERREURS
    -- =========================================================================

    END TRY

    BEGIN CATCH

        -- Afficher un séparateur.
        PRINT '==========================================';


        -- Signaler qu'une erreur s'est produite pendant le chargement.
        PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER';


        -- Afficher le message détaillé de l'erreur.
        -- ERROR_MESSAGE() retourne le texte de l'erreur SQL Server.
        PRINT 'Error Message: ' + ERROR_MESSAGE();


        -- Afficher le numéro de l'erreur.
        -- ERROR_NUMBER() retourne le code numérique de l'erreur.
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);


        -- Afficher l'état associé à l'erreur.
        -- ERROR_STATE() fournit des informations supplémentaires
        -- permettant d'identifier le contexte de l'erreur.
        PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR);


        -- Afficher un dernier séparateur.
        PRINT '==========================================';

    END CATCH

END;

EXEC  bronze.load_bronze
