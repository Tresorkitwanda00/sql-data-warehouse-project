/*
===============================================================================
SCRIPT : CONTRÔLES QUALITÉ DES DONNÉES - COUCHE SILVER
===============================================================================

OBJECTIF DU SCRIPT :

    Ce script permet de vérifier la qualité, la cohérence, l'exactitude
    et la standardisation des données présentes dans la couche Silver.

    Il doit être exécuté APRÈS le chargement de la couche Silver.

    Architecture du processus :

        SOURCES
           ↓
        BRONZE
           ↓
        Transformation / Nettoyage
           ↓
        SILVER
           ↓
        CONTRÔLES QUALITÉ
           ↓
        GOLD


PRINCIPAUX CONTRÔLES EFFECTUÉS :

    1. Vérification des valeurs NULL dans les identifiants.
    2. Détection des doublons.
    3. Détection des espaces inutiles.
    4. Vérification de la standardisation des valeurs.
    5. Vérification des coûts négatifs ou NULL.
    6. Vérification de la cohérence des dates.
    7. Vérification des dates de naissance.
    8. Vérification de la cohérence :
           Ventes = Quantité × Prix
    9. Vérification de la cohérence entre les dates de commande,
       d'expédition et de livraison.
    10. Identification des valeurs inattendues dans les catégories,
        pays, genres et informations de maintenance.


INTERPRÉTATION DES RÉSULTATS :

    Pour les contrôles indiqués avec :

        -- Expectation: No Results

    le résultat attendu est normalement 0 ligne.

    Si une ou plusieurs lignes apparaissent, cela signifie qu'une anomalie
    a été détectée et qu'elle doit être analysée.


IMPORTANT :

    Ce script ne corrige pas les données.

    Il sert principalement à :

        DÉTECTER → ANALYSER → CORRIGER

    Les corrections sont généralement réalisées dans la procédure
    silver.load_silver.


===============================================================================
*/


-- ============================================================================
-- CONTRÔLES DE LA TABLE : silver.crm_cust_info
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. VÉRIFICATION DES NULLS ET DES DOUBLONS DANS cst_id
-- ---------------------------------------------------------------------------

-- On regroupe les lignes par identifiant client.
SELECT
    cst_id,

    -- Compter le nombre de lignes pour chaque client.
    COUNT(*)

FROM silver.crm_cust_info

-- Regrouper les données client par cst_id.
GROUP BY cst_id

-- Détecter :
--     - les identifiants présents plusieurs fois ;
--     - les identifiants NULL.
HAVING COUNT(*) > 1
    OR cst_id IS NULL;


/*
INTERPRÉTATION :

    Cette requête vérifie que cst_id peut jouer le rôle
    d'identifiant unique du client.

    Exemple problématique :

        cst_id
        ------
        101
        101
        102

    Le client 101 apparaît deux fois.

    Autre problème :

        cst_id
        ------
        101
        102
        NULL

    Un client sans identifiant est problématique.

    RÉSULTAT ATTENDU :
        Aucune ligne.

    Si aucune ligne n'est retournée :
        → aucun doublon détecté
        → aucun cst_id NULL détecté.
*/


-- ---------------------------------------------------------------------------
-- 2. VÉRIFICATION DES ESPACES INUTILES
-- ---------------------------------------------------------------------------

SELECT
    cst_key

FROM silver.crm_cust_info

-- Comparer la valeur originale avec la valeur après TRIM.
WHERE cst_key != TRIM(cst_key);


/*
TRIM() supprime les espaces situés au début et à la fin d'une chaîne.

Exemple :

    '  CUST-001  '

devient :

    'CUST-001'

Si la valeur originale est différente de sa version TRIM,
cela signifie qu'elle contient des espaces inutiles.

RÉSULTAT ATTENDU :
    Aucune ligne.
*/


-- ---------------------------------------------------------------------------
-- 3. VÉRIFICATION DE LA STANDARDISATION DE LA SITUATION MATRIMONIALE
-- ---------------------------------------------------------------------------

SELECT DISTINCT
    cst_marital_status

FROM silver.crm_cust_info;


/*
DISTINCT permet d'afficher uniquement les valeurs différentes.

Cette requête permet de vérifier si les valeurs sont correctement
standardisées.

On devrait normalement retrouver quelque chose comme :

    Single
    Married
    n/a

et éviter des valeurs incohérentes comme :

    S
    M
    single
    married
    UNKNOWN

Cela permet de contrôler que la transformation effectuée
dans silver.load_silver a bien fonctionné.
*/


-- ============================================================================
-- CONTRÔLES DE LA TABLE : silver.crm_prd_info
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 4. VÉRIFICATION DES NULLS ET DES DOUBLONS DANS prd_id
-- ---------------------------------------------------------------------------

SELECT
    prd_id,

    -- Compter le nombre d'apparitions de chaque produit.
    COUNT(*)

FROM silver.crm_prd_info

GROUP BY prd_id

HAVING COUNT(*) > 1
    OR prd_id IS NULL;


/*
OBJECTIF :

    Vérifier que chaque produit possède un identifiant valide
    et qu'il n'existe pas plusieurs lignes identiques concernant
    le même identifiant produit.

RÉSULTAT ATTENDU :
    Aucune ligne.
*/


-- ---------------------------------------------------------------------------
-- 5. VÉRIFICATION DES ESPACES INUTILES DANS LE NOM DU PRODUIT
-- ---------------------------------------------------------------------------

SELECT
    prd_nm

FROM silver.crm_prd_info

WHERE prd_nm != TRIM(prd_nm);


/*
Exemple :

    ' Mountain Bike '

devrait devenir :

    'Mountain Bike'

Cette requête permet de détecter les noms contenant des espaces
inutiles au début ou à la fin.

RÉSULTAT ATTENDU :
    Aucune ligne.
*/


-- ---------------------------------------------------------------------------
-- 6. VÉRIFICATION DES COÛTS NULL OU NÉGATIFS
-- ---------------------------------------------------------------------------

SELECT
    prd_cost

FROM silver.crm_prd_info

WHERE prd_cost < 0
   OR prd_cost IS NULL;


/*
Un coût négatif n'est normalement pas valide.

Dans silver.load_silver, nous avons utilisé :

    ISNULL(prd_cost, 0)

pour remplacer les valeurs NULL par 0.

Ce contrôle permet donc de vérifier si cette transformation
a bien fonctionné.

RÉSULTAT ATTENDU :
    Aucune ligne.

ATTENTION :

    Une valeur 0 n'est pas détectée ici comme erreur.

    La requête vérifie uniquement :

        prd_cost < 0
        OU
        prd_cost IS NULL
*/


-- ---------------------------------------------------------------------------
-- 7. VÉRIFICATION DE LA STANDARDISATION DE LA LIGNE PRODUIT
-- ---------------------------------------------------------------------------

SELECT DISTINCT
    prd_line

FROM silver.crm_prd_info;


/*
Cette requête affiche toutes les valeurs différentes de prd_line.

Les valeurs attendues sont normalement :

    Mountain
    Road
    Other Sales
    Touring
    n/a

Elle permet de vérifier que les codes :

    M
    R
    S
    T

ont bien été transformés en valeurs lisibles.
*/


-- ---------------------------------------------------------------------------
-- 8. VÉRIFICATION DE LA COHÉRENCE DES DATES PRODUIT
-- ---------------------------------------------------------------------------

SELECT
    *

FROM silver.crm_prd_info

-- Une date de fin ne doit pas être antérieure
-- à la date de début.
WHERE prd_end_dt < prd_start_dt;


/*
Exemple incorrect :

    prd_start_dt = 2025-01-01
    prd_end_dt   = 2024-12-31

La période serait impossible.

RÉSULTAT ATTENDU :
    Aucune ligne.

NOTE :

    prd_end_dt peut être NULL pour le produit actuellement actif.

    NULL < prd_start_dt n'est pas TRUE en SQL,
    donc cette ligne ne sera pas retournée par ce contrôle.
*/


-- ============================================================================
-- CONTRÔLES DE LA TABLE : silver.crm_sales_details
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 9. VÉRIFICATION DES DATES BRUTES DANS BRONZE
-- ---------------------------------------------------------------------------

SELECT
    NULLIF(sls_due_dt, 0) AS sls_due_dt

FROM bronze.crm_sales_details

WHERE sls_due_dt <= 0
   OR LEN(sls_due_dt) != 8
   OR sls_due_dt > 20500101
   OR sls_due_dt < 19000101;


/*
ATTENTION :

    Ici, le contrôle porte directement sur la table BRONZE
    et non sur la table SILVER.

Pourquoi ?

Parce que dans Bronze, les dates sont encore stockées sous
forme numérique.

Exemple :

    20250115

correspond à :

    15 janvier 2025.


Le contrôle recherche des valeurs :

    <= 0
    → date inexistante ou invalide

    LEN(...) != 8
    → format incorrect

    > 20500101
    → date trop éloignée dans le futur

    < 19000101
    → date trop ancienne


NULLIF(sls_due_dt, 0)

transforme :

    0 → NULL

Cela facilite la représentation des dates invalides.

IMPORTANT :

    Ce contrôle permet de vérifier la qualité des données AVANT
    ou indépendamment de leur transformation en Silver.
*/


-- ---------------------------------------------------------------------------
-- 10. VÉRIFICATION DE L'ORDRE CHRONOLOGIQUE DES DATES
-- ---------------------------------------------------------------------------

SELECT
    *

FROM silver.crm_sales_details

WHERE sls_order_dt > sls_ship_dt
   OR sls_order_dt > sls_due_dt;


/*
LOGIQUE MÉTIER :

Normalement :

    Date commande
         ↓
    Date expédition
         ↓
    Date prévue de livraison


Donc :

    sls_order_dt <= sls_ship_dt
    sls_order_dt <= sls_due_dt


Exemple incorrect :

    Commande    : 2025-06-20
    Expédition  : 2025-06-15

Impossible :

    Le produit aurait été expédié avant la commande.


RÉSULTAT ATTENDU :
    Aucune ligne.
*/


-- ---------------------------------------------------------------------------
-- 11. VÉRIFICATION DE LA COHÉRENCE DES VENTES
-- ---------------------------------------------------------------------------

SELECT DISTINCT

    -- Montant de la vente.
    sls_sales,

    -- Quantité vendue.
    sls_quantity,

    -- Prix unitaire.
    sls_price

FROM silver.crm_sales_details


-- Détecter les incohérences.
WHERE sls_sales != sls_quantity * sls_price

   -- Vérifier également les valeurs NULL.
   OR sls_sales IS NULL
   OR sls_quantity IS NULL
   OR sls_price IS NULL

   -- Vérifier que les valeurs sont positives.
   OR sls_sales <= 0
   OR sls_quantity <= 0
   OR sls_price <= 0


-- Trier les anomalies pour faciliter leur analyse.
ORDER BY
    sls_sales,
    sls_quantity,
    sls_price;


/*
RELATION MÉTIER :

    VENTES = QUANTITÉ × PRIX

Exemple correct :

    Quantity = 5
    Price    = 100
    Sales    = 500

Exemple incorrect :

    Quantity = 5
    Price    = 100
    Sales    = 700


Cette requête permet donc de détecter :

    - ventes incorrectes ;
    - prix incorrects ;
    - quantités incorrectes ;
    - valeurs NULL ;
    - valeurs négatives ou nulles.


RÉSULTAT ATTENDU :
    Aucune ligne.
*/


-- ============================================================================
-- CONTRÔLES DE LA TABLE : silver.erp_cust_az12
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 12. VÉRIFICATION DES DATES DE NAISSANCE
-- ---------------------------------------------------------------------------

SELECT DISTINCT
    bdate

FROM silver.erp_cust_az12

WHERE bdate < '1924-01-01'
   OR bdate > GETDATE();


/*
OBJECTIF :

    Vérifier que les dates de naissance sont plausibles.

La règle appliquée ici est :

    bdate >= 1924-01-01
    ET
    bdate <= aujourd'hui


Une date de naissance située dans le futur est impossible.

Exemple :

    2030-05-10

est invalide si nous sommes en 2026.


RÉSULTAT ATTENDU :
    Aucune ligne.


NOTE :

    La limite 1924 est une règle métier choisie pour ce projet.
    Elle peut être adaptée selon le contexte réel des données.
*/


-- ---------------------------------------------------------------------------
-- 13. VÉRIFICATION DE LA STANDARDISATION DU GENRE
-- ---------------------------------------------------------------------------

SELECT DISTINCT
    gen

FROM silver.erp_cust_az12;


/*
Cette requête permet de vérifier les différentes valeurs présentes
dans la colonne gen.

Les valeurs attendues sont normalement :

    Female
    Male
    n/a


Les valeurs telles que :

    F
    M
    FEMALE
    MALE

devraient avoir été standardisées lors du chargement Silver.
*/


-- ============================================================================
-- CONTRÔLES DE LA TABLE : silver.erp_loc_a101
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 14. VÉRIFICATION DE LA STANDARDISATION DES PAYS
-- ---------------------------------------------------------------------------

SELECT DISTINCT
    cntry

FROM silver.erp_loc_a101

-- Trier les pays par ordre alphabétique
-- pour faciliter leur lecture.
ORDER BY cntry;


/*
Cette requête permet de vérifier les différentes valeurs de pays.

Elle permet notamment de vérifier que :

    DE
        ↓
    Germany

et :

    US
    USA
        ↓
    United States


Elle permet également de repérer d'éventuelles valeurs inattendues.

Exemple :

    Germany
    United States
    France
    Brazil
    n/a

seraient des valeurs plausibles.

Si on trouve :

    DE
    USA
    US

cela signifie que la standardisation n'a peut-être pas été
correctement appliquée.
*/


-- ============================================================================
-- CONTRÔLES DE LA TABLE : silver.erp_px_cat_g1v2
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 15. VÉRIFICATION DES ESPACES INUTILES
-- ---------------------------------------------------------------------------

SELECT
    *

FROM silver.erp_px_cat_g1v2

WHERE cat != TRIM(cat)
   OR subcat != TRIM(subcat)
   OR maintenance != TRIM(maintenance);


/*
Cette requête vérifie trois colonnes :

    cat
    subcat
    maintenance


Elle recherche des espaces inutiles au début ou à la fin
des chaînes de caractères.

Exemple :

    'Bikes '

sera détecté car :

    'Bikes ' != TRIM('Bikes ')


RÉSULTAT ATTENDU :
    Aucune ligne.
*/


-- ---------------------------------------------------------------------------
-- 16. VÉRIFICATION DE LA STANDARDISATION DE LA MAINTENANCE
-- ---------------------------------------------------------------------------

SELECT DISTINCT
    maintenance

FROM silver.erp_px_cat_g1v2;


/*
Cette requête affiche toutes les valeurs différentes présentes
dans la colonne maintenance.

Elle permet de détecter :

    - les valeurs inattendues ;
    - les valeurs mal orthographiées ;
    - les valeurs incohérentes ;
    - les valeurs NULL ou vides.

C'est un contrôle de standardisation et de cohérence.
*/
