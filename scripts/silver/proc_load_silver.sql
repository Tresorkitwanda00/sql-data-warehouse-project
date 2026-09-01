/*
===============================================================================
Procédure stockée : Chargement de la couche Silver (Bronze -> Silver)
===============================================================================

OBJECTIF :
    Cette procédure stockée réalise le processus ETL permettant de transformer
    les données présentes dans la couche Bronze avant de les charger dans
    la couche Silver.

    ETL signifie :

        E = Extract    -> Extraire les données
        T = Transform  -> Nettoyer et transformer les données
        L = Load       -> Charger les données transformées

    Dans cette procédure, les données sont déjà présentes dans Bronze.
    Le processus réalisé est donc principalement :

        BRONZE
           |
           | Nettoyage
           | Standardisation
           | Transformation
           | Contrôle
           ↓
        SILVER


ACTIONS PRINCIPALES :
    - Vider les tables Silver avant chaque chargement.
    - Lire les données depuis les tables Bronze.
    - Nettoyer les espaces inutiles.
    - Standardiser les valeurs textuelles.
    - Convertir les dates dans le bon format.
    - Corriger certaines valeurs incohérentes.
    - Dédupliquer les clients.
    - Calculer certaines informations dérivées.
    - Charger les données transformées dans Silver.
    - Mesurer la durée du chargement.
    - Gérer les erreurs éventuelles.

PARAMÈTRES :
    Aucun paramètre.

EXÉCUTION :
    EXEC silver.load_silver;

===============================================================================
*/


-- ============================================================================
-- CRÉATION OU MODIFICATION DE LA PROCÉDURE STOCKÉE
-- ============================================================================

-- CREATE OR ALTER permet :
--     - de créer la procédure si elle n'existe pas ;
--     - de modifier la procédure si elle existe déjà.
--
-- La procédure est créée dans le schéma 'silver'.
CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN


    -- ========================================================================
    -- DÉCLARATION DES VARIABLES DE TEMPS
    -- ========================================================================

    -- @start_time :
    --     heure de début du chargement d'une table.

    -- @end_time :
    --     heure de fin du chargement d'une table.

    -- @batch_start_time :
    --     heure de début du processus global Bronze -> Silver.

    -- @batch_end_time :
    --     heure de fin du processus global.
    DECLARE
        @start_time DATETIME,
        @end_time DATETIME,
        @batch_start_time DATETIME,
        @batch_end_time DATETIME;


    -- ========================================================================
    -- DÉBUT DU TRAITEMENT
    -- ========================================================================

    -- BEGIN TRY permet d'exécuter le processus tout en pouvant
    -- intercepter les erreurs dans le bloc BEGIN CATCH.
    BEGIN TRY


        -- Enregistrer la date et l'heure du début du chargement global.
        SET @batch_start_time = GETDATE();


        -- Afficher le début du traitement dans la console SQL Server.
        PRINT '================================================';
        PRINT 'Loading Silver Layer';
        PRINT '================================================';


        -- ====================================================================
        -- CHARGEMENT DES TABLES CRM
        -- ====================================================================

        PRINT '------------------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '------------------------------------------------';


        -- ====================================================================
        -- 1. CHARGEMENT DE silver.crm_cust_info
        -- ====================================================================

        -- Enregistrer l'heure de début du traitement de cette table.
        SET @start_time = GETDATE();


        -- Afficher la table qui va être vidée.
        PRINT '>> Truncating Table: silver.crm_cust_info';


        -- Supprimer toutes les données existantes de la table Silver.
        --
        -- Cette procédure utilise un chargement complet :
        -- Bronze -> Silver.
        TRUNCATE TABLE silver.crm_cust_info;


        -- Afficher le début de l'insertion.
        PRINT '>> Inserting Data Into: silver.crm_cust_info';


        -- Insérer les données transformées dans la table Silver.
        INSERT INTO silver.crm_cust_info (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date
        )


        -- ====================================================================
        -- EXTRACTION ET TRANSFORMATION DES DONNÉES CLIENTS
        -- ====================================================================

        SELECT

            -- Identifiant du client.
            cst_id,

            -- Clé métier du client.
            cst_key,


            -- TRIM supprime les espaces inutiles au début et à la fin
            -- du prénom.
            --
            -- Exemple :
            --     '  John  ' -> 'John'
            TRIM(cst_firstname) AS cst_firstname,


            -- Supprimer les espaces inutiles autour du nom.
            TRIM(cst_lastname) AS cst_lastname,


            -- =================================================================
            -- STANDARDISATION DE LA SITUATION MATRIMONIALE
            -- =================================================================

            CASE

                -- UPPER transforme la valeur en majuscules.
                -- TRIM supprime les espaces inutiles.
                --
                -- Exemple :
                --     ' s ' -> 'S'
                WHEN UPPER(TRIM(cst_marital_status)) = 'S'
                    THEN 'Single'


                -- M signifie Married.
                WHEN UPPER(TRIM(cst_marital_status)) = 'M'
                    THEN 'Married'


                -- Toute valeur inconnue ou vide devient 'n/a'.
                ELSE 'n/a'

            END AS cst_marital_status,


            -- =================================================================
            -- STANDARDISATION DU GENRE
            -- =================================================================

            CASE

                -- F devient Female.
                WHEN UPPER(TRIM(cst_gndr)) = 'F'
                    THEN 'Female'


                -- M devient Male.
                WHEN UPPER(TRIM(cst_gndr)) = 'M'
                    THEN 'Male'


                -- Valeur inconnue ou non reconnue.
                ELSE 'n/a'

            END AS cst_gndr,


            -- Conserver la date de création du client.
            cst_create_date


        -- ====================================================================
        -- SOUS-REQUÊTE DE DÉDUPLICATION
        -- ====================================================================

        FROM (

            SELECT

                -- Récupérer toutes les colonnes de la table Bronze.
                *,


                -- ROW_NUMBER attribue un numéro à chaque ligne
                -- à l'intérieur de chaque groupe de clients.
                --
                -- PARTITION BY cst_id :
                --     regroupe les lignes appartenant au même client.
                --
                -- ORDER BY cst_create_date DESC :
                --     place la ligne la plus récente en premier.
                --
                -- Exemple :
                --
                -- Client 100
                -- 2023-01-01 -> 3
                -- 2024-05-10 -> 2
                -- 2025-08-20 -> 1
                --
                -- Le client le plus récent reçoit donc flag_last = 1.
                ROW_NUMBER() OVER (
                    PARTITION BY cst_id
                    ORDER BY cst_create_date DESC
                ) AS flag_last


            -- Source des données : table Bronze.
            FROM bronze.crm_cust_info


            -- Ne conserver que les clients possédant un identifiant.
            WHERE cst_id IS NOT NULL

        ) t


        -- Conserver uniquement la ligne la plus récente
        -- pour chaque client.
        WHERE flag_last = 1;


        -- Enregistrer l'heure de fin du traitement.
        SET @end_time = GETDATE();


        -- Calculer et afficher la durée du chargement.
        PRINT '>> Load Duration: '
            + CAST(
                DATEDIFF(SECOND, @start_time, @end_time)
                AS NVARCHAR
            )
            + ' seconds';


        PRINT '>> -------------';


        -- ====================================================================
        -- 2. CHARGEMENT DE silver.crm_prd_info
        -- ====================================================================

        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: silver.crm_prd_info';

        -- Vider la table Silver avant le nouveau chargement.
        TRUNCATE TABLE silver.crm_prd_info;

        PRINT '>> Inserting Data Into: silver.crm_prd_info';


        -- Définir les colonnes de destination.
        INSERT INTO silver.crm_prd_info (
            prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt
        )


        SELECT

            -- Identifiant du produit.
            prd_id,


            -- =================================================================
            -- EXTRACTION DE LA CATÉGORIE
            -- =================================================================

            -- SUBSTRING(prd_key, 1, 5) récupère les 5 premiers caractères
            -- de la clé produit.
            --
            -- Exemple :
            --     prd_key = 'CO-001-ABC'
            --     SUBSTRING(...) -> 'CO-00'
            --
            -- REPLACE remplace le caractère '-' par '_'.
            REPLACE(
                SUBSTRING(prd_key, 1, 5),
                '-',
                '_'
            ) AS cat_id,


            -- =================================================================
            -- EXTRACTION DE LA CLÉ PRODUIT
            -- =================================================================

            -- SUBSTRING commence à la position 7 et récupère
            -- le reste de la chaîne.
            --
            -- Cela permet de retirer la partie correspondant
            -- à la catégorie de la clé produit.
            SUBSTRING(
                prd_key,
                7,
                LEN(prd_key)
            ) AS prd_key,


            -- Nom du produit.
            prd_nm,


            -- Si le coût est NULL, remplacer NULL par 0.
            --
            -- Exemple :
            --     NULL -> 0
            ISNULL(prd_cost, 0) AS prd_cost,


            -- =================================================================
            -- STANDARDISATION DE LA LIGNE PRODUIT
            -- =================================================================

            CASE

                -- M devient Mountain.
                WHEN UPPER(TRIM(prd_line)) = 'M'
                    THEN 'Mountain'

                -- R devient Road.
                WHEN UPPER(TRIM(prd_line)) = 'R'
                    THEN 'Road'

                -- S devient Other Sales.
                WHEN UPPER(TRIM(prd_line)) = 'S'
                    THEN 'Other Sales'

                -- T devient Touring.
                WHEN UPPER(TRIM(prd_line)) = 'T'
                    THEN 'Touring'

                -- Valeur inconnue.
                ELSE 'n/a'

            END AS prd_line,


            -- Convertir la date de début en type DATE.
            --
            -- Cela supprime éventuellement la partie heure.
            CAST(prd_start_dt AS DATE) AS prd_start_dt,


            -- =================================================================
            -- CALCUL DE LA DATE DE FIN
            -- =================================================================

            -- LEAD permet de récupérer la date de début de la prochaine
            -- ligne appartenant au même produit.
            --
            -- PARTITION BY prd_key :
            --     travailler produit par produit.
            --
            -- ORDER BY prd_start_dt :
            --     classer les périodes du produit par date croissante.
            --
            -- On retire ensuite 1 jour à la prochaine date de début
            -- pour obtenir la date de fin de la période actuelle.
            --
            -- Exemple :
            --
            -- Produit A
            -- Début : 2024-01-01
            -- Début suivant : 2024-06-01
            --
            -- Fin :
            -- 2024-05-31
            CAST(
                LEAD(prd_start_dt) OVER (
                    PARTITION BY prd_key
                    ORDER BY prd_start_dt
                ) - 1
                AS DATE
            ) AS prd_end_dt


        -- Source des produits : table Bronze.
        FROM bronze.crm_prd_info;


        -- Enregistrer la fin du chargement.
        SET @end_time = GETDATE();


        -- Afficher la durée.
        PRINT '>> Load Duration: '
            + CAST(
                DATEDIFF(SECOND, @start_time, @end_time)
                AS NVARCHAR
            )
            + ' seconds';

        PRINT '>> -------------';


        -- ====================================================================
        -- 3. CHARGEMENT DE silver.crm_sales_details
        -- ====================================================================

        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: silver.crm_sales_details';

        -- Vider la table Silver.
        TRUNCATE TABLE silver.crm_sales_details;

        PRINT '>> Inserting Data Into: silver.crm_sales_details';


        -- Définir les colonnes de destination.
        INSERT INTO silver.crm_sales_details (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )


        SELECT

            -- Numéro de commande.
            sls_ord_num,

            -- Clé du produit.
            sls_prd_key,

            -- Identifiant du client.
            sls_cust_id,


            -- =================================================================
            -- CONVERSION DE LA DATE DE COMMANDE
            -- =================================================================

            CASE

                -- Si la date vaut 0 ou ne possède pas 8 caractères,
                -- elle est considérée comme invalide.
                WHEN sls_order_dt = 0
                     OR LEN(sls_order_dt) != 8
                    THEN NULL

                -- Sinon, convertir l'entier en texte puis en DATE.
                --
                -- Exemple :
                --     20250115
                --          ↓
                --     '20250115'
                --          ↓
                --     2025-01-15
                ELSE CAST(
                    CAST(sls_order_dt AS VARCHAR)
                    AS DATE
                )

            END AS sls_order_dt,


            -- =================================================================
            -- CONVERSION DE LA DATE D'EXPÉDITION
            -- =================================================================

            CASE

                WHEN sls_ship_dt = 0
                     OR LEN(sls_ship_dt) != 8
                    THEN NULL

                ELSE CAST(
                    CAST(sls_ship_dt AS VARCHAR)
                    AS DATE
                )

            END AS sls_ship_dt,


            -- =================================================================
            -- CONVERSION DE LA DATE PRÉVUE DE LIVRAISON
            -- =================================================================

            CASE

                WHEN sls_due_dt = 0
                     OR LEN(sls_due_dt) != 8
                    THEN NULL

                ELSE CAST(
                    CAST(sls_due_dt AS VARCHAR)
                    AS DATE
                )

            END AS sls_due_dt,


            -- =================================================================
            -- CONTRÔLE ET RECALCUL DU MONTANT DES VENTES
            -- =================================================================

            CASE

                -- Si le montant des ventes est NULL,
                -- inférieur ou égal à zéro,
                -- OU différent de :
                --
                -- quantité × prix absolu
                --
                -- alors on recalcule le montant.
                WHEN sls_sales IS NULL
                     OR sls_sales <= 0
                     OR sls_sales != sls_quantity * ABS(sls_price)

                    THEN sls_quantity * ABS(sls_price)


                -- Sinon, conserver la valeur originale.
                ELSE sls_sales

            END AS sls_sales,


            -- Quantité vendue.
            sls_quantity,


            -- =================================================================
            -- CONTRÔLE ET RECALCUL DU PRIX
            -- =================================================================

            CASE

                -- Si le prix est NULL ou inférieur/égal à zéro,
                -- calculer le prix à partir :
                --
                -- ventes / quantité
                --
                -- NULLIF évite une division par zéro.
                WHEN sls_price IS NULL
                     OR sls_price <= 0

                    THEN sls_sales
                         / NULLIF(sls_quantity, 0)


                -- Sinon conserver le prix original.
                ELSE sls_price

            END AS sls_price


        -- Source des données : table Bronze.
        FROM bronze.crm_sales_details;


        -- Enregistrer l'heure de fin.
        SET @end_time = GETDATE();


        -- Afficher la durée du traitement.
        PRINT '>> Load Duration: '
            + CAST(
                DATEDIFF(SECOND, @start_time, @end_time)
                AS NVARCHAR
            )
            + ' seconds';

        PRINT '>> -------------';


        -- ====================================================================
        -- 4. CHARGEMENT DE silver.erp_cust_az12
        -- ====================================================================

        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: silver.erp_cust_az12';

        -- Vider la table Silver.
        TRUNCATE TABLE silver.erp_cust_az12;

        PRINT '>> Inserting Data Into: silver.erp_cust_az12';


        -- Définir les colonnes de destination.
        INSERT INTO silver.erp_cust_az12 (
            cid,
            bdate,
            gen
        )


        SELECT

            -- =================================================================
            -- NETTOYAGE DE L'IDENTIFIANT CLIENT
            -- =================================================================

            CASE

                -- Si l'identifiant commence par 'NAS',
                -- supprimer ce préfixe.
                --
                -- Exemple :
                --     NAS12345
                --          ↓
                --     12345
                WHEN cid LIKE 'NAS%'
                    THEN SUBSTRING(
                        cid,
                        4,
                        LEN(cid)
                    )

                -- Sinon, conserver l'identifiant original.
                ELSE cid

            END AS cid,


            -- =================================================================
            -- CONTRÔLE DE LA DATE DE NAISSANCE
            -- =================================================================

            CASE

                -- Une date de naissance située dans le futur
                -- est considérée comme incorrecte.
                WHEN bdate > GETDATE()
                    THEN NULL

                -- Sinon conserver la date.
                ELSE bdate

            END AS bdate,


            -- =================================================================
            -- STANDARDISATION DU GENRE
            -- =================================================================

            CASE

                -- Accepter F ou FEMALE.
                WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE')
                    THEN 'Female'


                -- Accepter M ou MALE.
                WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')
                    THEN 'Male'


                -- Toute autre valeur est considérée comme inconnue.
                ELSE 'n/a'

            END AS gen


        -- Source : table Bronze ERP.
        FROM bronze.erp_cust_az12;


        -- Enregistrer l'heure de fin.
        SET @end_time = GETDATE();


        -- Afficher la durée.
        PRINT '>> Load Duration: '
            + CAST(
                DATEDIFF(SECOND, @start_time, @end_time)
                AS NVARCHAR
            )
            + ' seconds';

        PRINT '>> -------------';


        -- ====================================================================
        -- CHARGEMENT DES TABLES ERP
        -- ====================================================================

        PRINT '------------------------------------------------';
        PRINT 'Loading ERP Tables';
        PRINT '------------------------------------------------';


        -- ====================================================================
        -- 5. CHARGEMENT DE silver.erp_loc_a101
        -- ====================================================================

        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: silver.erp_loc_a101';

        -- Vider la table Silver.
        TRUNCATE TABLE silver.erp_loc_a101;

        PRINT '>> Inserting Data Into: silver.erp_loc_a101';


        -- Définir les colonnes de destination.
        INSERT INTO silver.erp_loc_a101 (
            cid,
            cntry
        )


        SELECT

            -- =================================================================
            -- NETTOYAGE DE L'IDENTIFIANT CLIENT
            -- =================================================================

            -- Supprimer les tirets présents dans l'identifiant.
            --
            -- Exemple :
            --     '12-345-678'
            --          ↓
            --     '12345678'
            REPLACE(cid, '-', '') AS cid,


            -- =================================================================
            -- STANDARDISATION DU PAYS
            -- =================================================================

            CASE

                -- DE devient Germany.
                WHEN TRIM(cntry) = 'DE'
                    THEN 'Germany'


                -- US et USA deviennent United States.
                WHEN TRIM(cntry) IN ('US', 'USA')
                    THEN 'United States'


                -- Si le pays est vide ou NULL,
                -- utiliser 'n/a'.
                WHEN TRIM(cntry) = ''
                     OR cntry IS NULL
                    THEN 'n/a'


                -- Pour les autres pays :
                -- supprimer les espaces inutiles.
                ELSE TRIM(cntry)

            END AS cntry


        -- Source : table Bronze ERP.
        FROM bronze.erp_loc_a101;


        -- Enregistrer l'heure de fin.
        SET @end_time = GETDATE();


        -- Afficher la durée du chargement.
        PRINT '>> Load Duration: '
            + CAST(
                DATEDIFF(SECOND, @start_time, @end_time)
                AS NVARCHAR
            )
            + ' seconds';

        PRINT '>> -------------';


        -- ====================================================================
        -- 6. CHARGEMENT DE silver.erp_px_cat_g1v2
        -- ====================================================================

        SET @start_time = GETDATE();

        PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';

        -- Vider la table Silver.
        TRUNCATE TABLE silver.erp_px_cat_g1v2;

        PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';


        -- Définir les colonnes de destination.
        INSERT INTO silver.erp_px_cat_g1v2 (
            id,
            cat,
            subcat,
            maintenance
        )


        SELECT

            -- Identifiant de la catégorie ou du produit.
            id,

            -- Catégorie principale.
            cat,

            -- Sous-catégorie.
            subcat,

            -- Information de maintenance.
            maintenance


        -- Source : table Bronze ERP.
        FROM bronze.erp_px_cat_g1v2;


        -- Enregistrer l'heure de fin.
        SET @end_time = GETDATE();


        -- Afficher la durée du traitement.
        PRINT '>> Load Duration: '
            + CAST(
                DATEDIFF(SECOND, @start_time, @end_time)
                AS NVARCHAR
            )
            + ' seconds';

        PRINT '>> -------------';


        -- ====================================================================
        -- FIN DU PROCESSUS GLOBAL
        -- ====================================================================

        -- Enregistrer l'heure de fin du chargement global.
        SET @batch_end_time = GETDATE();


        -- Afficher un séparateur.
        PRINT '==========================================';


        -- Indiquer que le chargement Silver est terminé.
        PRINT 'Loading Silver Layer is Completed';


        -- Calculer la durée totale du processus Bronze -> Silver.
        PRINT '   - Total Load Duration: '
            + CAST(
                DATEDIFF(
                    SECOND,
                    @batch_start_time,
                    @batch_end_time
                )
                AS NVARCHAR
            )
            + ' seconds';


        -- Afficher un dernier séparateur.
        PRINT '==========================================';


    -- ========================================================================
    -- GESTION DES ERREURS
    -- ========================================================================

    END TRY

    BEGIN CATCH

        -- Afficher un séparateur.
        PRINT '==========================================';


        -- Signaler qu'une erreur s'est produite.
        PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER';


        -- Afficher le message détaillé de l'erreur.
        PRINT 'Error Message: '
            + ERROR_MESSAGE();


        -- Afficher le numéro de l'erreur.
        PRINT 'Error Number: '
            + CAST(ERROR_NUMBER() AS NVARCHAR);


        -- Afficher l'état de l'erreur.
        PRINT 'Error State: '
            + CAST(ERROR_STATE() AS NVARCHAR);


        -- Afficher un dernier séparateur.
        PRINT '==========================================';

    END CATCH

END;
EXEC silver.load_silver
