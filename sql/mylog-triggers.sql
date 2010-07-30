-- ------------------------------------------------------------
-- -  Mylog PostgreSQL Triggers Version: 3.1.2
-- ------------------------------------------------------------


CREATE OR REPLACE FUNCTION mylog.selsert(IN str CHARACTER) RETURNS int AS
$$
DECLARE
    _id integer;
BEGIN
SELECT "id" INTO "_id" FROM "table" WHERE "key" = str;
IF found THEN
    RETURN "_id";
END IF;

INSERT INTO "table" ("id","key") VALUES (DEFAULT, str) RETURNING "id";

EXCEPTION WHEN unique_violation THEN
    -- someone else inserted an id faster than us
    SELECT "id" INTO "_id" FROM "table" WHERE "key" = str;
    IF found THEN
        RETURN "_id";
    END IF;
    
    -- SHOULDN'T HAPPEN
END;
$$
LANGUAGE plpgsql;

