-- Se connecter à la base de données système "master".
-- "master" permet notamment de gérer les bases de données SQL Server.
USE master;
GO

-- Vérifier si une base de données appelée "DataWareHouse" existe déjà.
-- sys.databases contient la liste des bases de données présentes sur SQL Server.
-- SELECT 1 signifie : "je cherche simplement à savoir si une ligne existe".
IF EXISTS (
    SELECT 1
    FROM sys.databases
    WHERE name = 'DataWareHouse'
)
BEGIN

    -- Passer la base DataWareHouse en mode SINGLE_USER.
    -- Cela signifie qu'une seule connexion pourra utiliser la base.
    --
    -- WITH ROLLBACK IMMEDIATE force la fermeture des connexions existantes
    -- et annule immédiatement les transactions encore ouvertes.
    --
    -- Cette étape permet d'éviter l'erreur :
    -- "Cannot drop database because it is currently in use."
    ALTER DATABASE DataWareHouse
    SET SINGLE_USER
    WITH ROLLBACK IMMEDIATE;

    -- Supprimer complètement la base de données existante.
    DROP DATABASE DataWareHouse;

END;
GO

-- Créer une nouvelle base de données appelée DataWareHouse.
CREATE DATABASE DataWareHouse;
GO

-- Se connecter à la nouvelle base de données.
USE DataWareHouse;
GO

-- Créer le schéma "bronze".
-- Le schéma Bronze servira généralement à stocker les données
-- proches de leur état original après extraction.
CREATE SCHEMA bronze;
GO

-- Créer le schéma "silver".
-- Le schéma Silver servira généralement aux données nettoyées,
-- standardisées et transformées.
CREATE SCHEMA silver;
GO

-- Créer le schéma "gold".
-- Le schéma Gold contiendra généralement les données prêtes
-- pour l'analyse, les KPIs, les rapports et la BI.
CREATE SCHEMA gold;
GO
