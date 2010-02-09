-- ------------------------------------------------------------
-- -  Mylog PostgreSQL Views Version: 3.1.2
-- ------------------------------------------------------------

CREATE VIEW "view_user_id" AS (
  SELECT
    "n"."network" AS "network",
    "u"."nick" AS "nick",
    "u"."ident" AS "ident",
    "u"."hostname" AS "hostname"
  FROM "mylog"."user_id" "u"
    JOIN "mylog"."networks" "n" on "u"."network_id" = "n"."id"
);

CREATE VIEW "view_joins" AS (
  SELECT
    "j"."id" AS "id",
    "j"."timestamp" AS "timestamp",
    "c"."channel" AS "channel",
    "n"."network" AS "network",
    "u"."nick" AS "nick",
    "u"."ident" AS "ident",
    "u"."hostname" AS "hostname"
  FROM "mylog"."joins" "j"
    JOIN "mylog"."channels" "c" on "j"."channel_id" = "c"."id"
    JOIN "mylog"."networks" "c" on "j"."network_id" = "n"."id"
    JOIN "mylog"."user_id" "u"  on "j"."user_id" = "u"."id"
);

/*
CREATE VIEW "view_kicks" AS (
  SELECT
    "k"."id" AS "id",
    "k"."timestamp" AS "timestamp",
    "c"."channel" AS "channel",
    "c"."network" AS "network",
    "v2"."nick" AS "kicked_nick",
    "v2"."ident" AS "kicked_ident",
    "v2"."hostname" AS "kicked_host",
    "v1"."nick" AS "kicker_nick",
    "v1"."ident" AS "kicker_ident",
    "v1"."hostname" AS "kicker_host",
    "q"."reason" AS "reason"
  FROM "kicks" "k"
    JOIN "view_user_id" "v1" on "v1"."id" = "k"."kicker_user_id"
    JOIN "view_user_id" "v2" on "v2"."id" = "k"."kicked_user_id"
    JOIN "reasons" "q" on "q"."id" = "k"."reason_id"
    JOIN "channels" "c" on "c"."id" = "k"."channel_id"
);
*/

CREATE VIEW "view_messages" AS (
  SELECT
    "m"."id" AS "id",
    "m"."timestamp" AS "timestamp",
    "c"."channel" AS "channel",
    "n"."network" AS "network",
    "u"."nick" AS "nick",
    "u"."ident" AS "ident",
    "u"."hostname" AS "hostname",
    "m"."message" AS "message"
  FROM "mylog"."messages" "m"
    JOIN "mylog"."channels" "c" on "m"."channel_id" = "c"."id"
    JOIN "mylog"."networks" "n" on "m"."network_id" = "n"."id"
    JOIN "mylog"."user_id"  "u" on "m"."user_id" = "u"."id" 
);  

/*
CREATE VIEW "view_nick_changes" AS (
  SELECT
    "nc"."id" AS "id",
    "nc"."timestamp" AS "timestamp",
    "oid"."nick" AS "old_nick",
    "nid"."nick" AS "new_nick"
  FROM "nick_changes" "nc"
    JOIN "view_user_id" "oid" on "oid"."id" = "nc"."old_user_id"
    JOIN "view_user_id" "nid" on "nid"."id" = "nc"."new_user_id"
);
*/

/*
CREATE VIEW "view_parts" AS (
  SELECT
    "p"."id" AS "id",
    "p"."timestamp" AS "timestamp",
    "c"."channel" AS "channel",
    "c"."network" AS "network",
    "v"."nick" AS "nick",
    "v"."ident" AS "ident",
    "v"."hostname" AS "hostname",
    "q"."reason" AS "reason"
  FROM "parts" "p"
    JOIN "view_user_id" "v" on "p"."user_id" = "v"."id"
    JOIN "channels" "c" on "p"."channel_id" = "c"."id" 
    JOIN "reasons" "q" on "p"."reason_id" = "q"."id"
);
*/

/*
CREATE VIEW "view_quits" AS (
  SELECT
    "q"."id" AS "id",
    "q"."timestamp" AS "timestamp",
    "v"."nick" AS "nick",
    "v"."ident" AS "ident_name",
    "v"."hostname" AS "hostname",
    "m"."reason" AS "reason"
  FROM "quits" "q"
    JOIN "view_user_id" "v" on "v"."id" = "q"."user_id"
    JOIN "reasons" "m" on "m"."id" = "q"."reason_id"
);
*/

/*
CREATE VIEW "view_topics" AS (
  SELECT
    "t"."id" AS "id",
    "t"."timestamp" AS "timestamp",
    "c"."channel" AS "channel",
    "c"."network" AS "network",
    "v"."nick" AS "nick",
    "v"."ident" AS "ident",
    "v"."hostname" AS "hostname",
    "t"."topic" AS "topic"
  FROM  "topics" "t"
    JOIN "channels" "c" on "c"."id" = "t"."channel_id"
    JOIN "view_user_id" "v" on "v"."id" = "t"."user_id"
);
*/