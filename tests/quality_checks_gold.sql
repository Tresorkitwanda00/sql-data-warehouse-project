/*
===============================================================================
CONTRÔLES DE QUALITÉ DES DONNÉES (QUALITY CHECKS)
===============================================================================
OBJECTIF DU SCRIPT :
    Ce script effectue des contrôles de qualité pour valider l'intégrité,
    la cohérence et la précision de la couche Gold. Ces vérifications assurent :
        - L'unicité des clés substituts (surrogate keys) dans les dimensions.
        - L'intégrité référentielle entre la table de faits et les dimensions.
        - La validation des relations du modèle de données pour l'analyse BI.

NOTES D'UTILISATION :
    - Analyser et corriger toute anomalie ou résultat renvoyé par ces requêtes.
===============================================================================
*/


-- ============================================================================
-- 1. VÉRIFICATION DE LA DIMENSION CLIENTS ('gold.dim_customers')
-- ============================================================================

-- Vérification de l'unicité de la clé client (customer_key)
-- Résultat attendu : Aucun résultat (0 ligne renvoyée)
SELECT 
    customer_key,
    COUNT(*) AS nombre_doublons
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;


-- ============================================================================
-- 2. VÉRIFICATION DE LA DIMENSION PRODUITS ('gold.dim_products')
-- ============================================================================

-- Vérification de l'unicité de la clé produit (product_key)
-- Résultat attendu : Aucun résultat (0 ligne renvoyée)
SELECT 
    product_key,
    COUNT(*) AS nombre_doublons
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;


-- ============================================================================
-- 3. VÉRIFICATION DE LA TABLE DE FAITS ('gold.fact_sales')
-- ============================================================================

-- Vérification de l'intégrité référentielle entre la table de faits et les dimensions
-- Résultat attendu : Aucun résultat (si toutes les ventes sont bien associées à un client et un produit)
SELECT 
    f.order_number,
    f.customer_key AS fact_customer_key,
    c.customer_key AS dim_customer_key,
    f.product_key  AS fact_product_key,
    p.product_key  AS dim_product_key
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products AS p
    ON p.product_key = f.product_key
WHERE p.product_key IS NULL 
   OR c.customer_key IS NULL;
