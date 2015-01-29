/*~
-- ANCHORS AND ATTRIBUTES ---------------------------------------------------------------------------------------------
--
-- Anchors are used to store the identities of entities.
-- Anchors are immutable.
-- Attributes are used to store values for properties of entities.
-- Attributes are mutable, their values may change over one or more types of time.
-- Attributes have four flavors: static, historized, knotted static, and knotted historized.
-- Anchors may have zero or more adjoined attributes.
--
~*/
var anchor;

while (anchor = schema.nextAnchor()) {
    if(anchor.isGenerator()) {
    	schema.setIdentityGenerator(anchor);
    }

/*~
-- Anchor table -------------------------------------------------------------------------------------------------------
-- $anchor.name table (with ${(anchor.attributes ? anchor.attributes.length : 0)}$ attributes)
-----------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS _$anchor.name (
    $anchor.identityColumnName $(anchor.isGenerator())? $anchor.identityGenerator not null, : $anchor.identity not null,
    $(schema.METADATA)? $anchor.metadataColumnName $schema.metadata.metadataType not null, : $anchor.dummyColumnName boolean null,
    constraint pk$anchor.name primary key (
        $anchor.identityColumnName
    )
);

ALTER TABLE IF EXISTS ONLY _$anchor.name CLUSTER ON pk$anchor.name;

CREATE OR REPLACE VIEW $anchor.name AS SELECT * FROM _$anchor.name;
~*/
    var knot, attribute;
    while (attribute = anchor.nextAttribute()) {
        var scheme = schema.PARTITIONING ? ' ON EquivalenceScheme(' + attribute.equivalentColumnName + ')' : '';
        if(attribute.isHistorized() && !attribute.isKnotted()) {
/*~
-- Historized attribute table -----------------------------------------------------------------------------------------
-- $attribute.name table (on $anchor.name)
-----------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS _$attribute.name (
    $attribute.anchorReferenceName $anchor.identity not null,
    $(attribute.isEquivalent())? $attribute.equivalentColumnName $schema.metadata.equivalentRange not null,
    $attribute.valueColumnName $attribute.dataRange not null,
    $(attribute.hasChecksum())? $attribute.checksumColumnName bytea not null,
    $attribute.changingColumnName $attribute.timeRange not null,
    $(schema.METADATA)? $attribute.metadataColumnName $schema.metadata.metadataType not null,
    constraint fk$attribute.name foreign key (
        $attribute.anchorReferenceName
    ) references _$anchor.name($anchor.identityColumnName),
    constraint pk$attribute.name primary key (
        $(attribute.isEquivalent())? $attribute.equivalentColumnName,
        $attribute.anchorReferenceName,
        $attribute.changingColumnName
    )
)$(attribute.isEquivalent())? $scheme; : ;

ALTER TABLE IF EXISTS ONLY _$attribute.name CLUSTER ON pk$attribute.name;

CREATE OR REPLACE VIEW $attribute.name AS SELECT * FROM _$attribute.name;
~*/
    }
    else if(attribute.isHistorized() && attribute.isKnotted()) {
        knot = attribute.knot;
        var knotTableName = knot.isEquivalent() ? knot.identityName : knot.name;
/*~
-- Knotted historized attribute table ---------------------------------------------------------------------------------
-- $attribute.name table (on $anchor.name)
-----------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS _$attribute.name (
    $attribute.anchorReferenceName $anchor.identity not null,
    $attribute.knotReferenceName $knot.identity not null,
    $attribute.changingColumnName $attribute.timeRange not null,
    $(schema.METADATA)? $attribute.metadataColumnName $schema.metadata.metadataType not null,
    constraint fk_A_$attribute.name foreign key (
        $attribute.anchorReferenceName
    ) references _$anchor.name($anchor.identityColumnName),
    constraint fk_K_$attribute.name foreign key (
        $attribute.knotReferenceName
    ) references _$knotTableName($knot.identityColumnName),
    constraint pk$attribute.name primary key (
        $attribute.anchorReferenceName,
        $attribute.changingColumnName
    )
);

ALTER TABLE IF EXISTS ONLY _$attribute.name CLUSTER ON pk$attribute.name;

CREATE OR REPLACE VIEW $attribute.name AS SELECT * FROM _$attribute.name;
~*/
    }
    else if(attribute.isKnotted()) {
        knot = attribute.knot;
        var knotTableName = knot.isEquivalent() ? knot.identityName : knot.name;

/*~
-- Knotted static attribute table -------------------------------------------------------------------------------------
-- $attribute.name table (on $anchor.name)
-----------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS _$attribute.name (
    $attribute.anchorReferenceName $anchor.identity not null,
    $attribute.knotReferenceName $knot.identity not null,
    $(schema.METADATA)? $attribute.metadataColumnName $schema.metadata.metadataType not null,
    constraint fk_A_$attribute.name foreign key (
        $attribute.anchorReferenceName
    ) references _$anchor.name($anchor.identityColumnName),
    constraint fk_K_$attribute.name foreign key (
        $attribute.knotReferenceName
    ) references _$knotTableName($knot.identityColumnName),
    constraint pk$attribute.name primary key (
        $attribute.anchorReferenceName
    )
);

ALTER TABLE IF EXISTS ONLY _$attribute.name CLUSTER ON pk$attribute.name;

CREATE OR REPLACE VIEW $attribute.name AS SELECT * FROM _$attribute.name;
~*/
    }
    else {
/*~
-- Static attribute table ---------------------------------------------------------------------------------------------
-- $attribute.name table (on $anchor.name)
-----------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS _$attribute.name (
    $attribute.anchorReferenceName $anchor.identity not null,
    $(attribute.isEquivalent())? $attribute.equivalentColumnName $schema.metadata.equivalentRange not null,
    $attribute.valueColumnName $attribute.dataRange not null,
    $(attribute.hasChecksum())? $attribute.checksumColumnName bytea not null,
    $(schema.METADATA)? $attribute.metadataColumnName $schema.metadata.metadataType not null,
    constraint fk$attribute.name foreign key (
        $attribute.anchorReferenceName
    ) references _$anchor.name($anchor.identityColumnName),
    constraint pk$attribute.name primary key (
        $(attribute.isEquivalent())? $attribute.equivalentColumnName,
        $attribute.anchorReferenceName
    )
)$(attribute.isEquivalent())? $scheme; : ;

ALTER TABLE IF EXISTS ONLY _$attribute.name CLUSTER ON pk$attribute.name;

CREATE OR REPLACE VIEW $attribute.name AS SELECT * FROM _$attribute.name;
~*/
    }
}}