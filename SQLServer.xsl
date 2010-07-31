<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="html" indent="no"/>

    <!-- lookup hash tables -->
	<xsl:key name="mnemonicToEntity" match="//*[@mnemonic]" use="@mnemonic"/>
    <xsl:key name="knotLookup" match="//knot[@mnemonic]" use="@mnemonic"/>
    <xsl:key name="anchorLookup" match="//anchor[@mnemonic]" use="@mnemonic"/>

    <!-- parameters controlling the output -->
    <xsl:param name="metadata">
        <xsl:text>_metadata int not null</xsl:text>
    </xsl:param>
    <xsl:param name="historizationSuffix">
        <xsl:text>ValidFrom</xsl:text>
    </xsl:param>
    <xsl:param name="identitySuffix">
        <xsl:text>ID</xsl:text>
    </xsl:param>

    <!-- "global" variables -->
    <xsl:variable name="N"><xsl:text>&#10;</xsl:text></xsl:variable>
    <xsl:variable name="T"><xsl:text>&#32;&#32;&#32;</xsl:text></xsl:variable>
    <xsl:variable name="Q"><xsl:text>'</xsl:text></xsl:variable>
    <xsl:variable name="metadataDefinition">
        <xsl:if test="normalize-space($metadata)">
            <xsl:value-of select="concat($T, $metadata, ',', $N)"/>
        </xsl:if>
    </xsl:variable>

    <!-- match the schema (root element) and process the different elements using for-each loops -->
	<xsl:template match="/schema">

		<!-- process all knots -->
		<xsl:for-each select="knot">
            <xsl:variable name="knotName" select="concat(@mnemonic, '_', @descriptor)"/>
            <xsl:variable name="knotIdentity" select="concat(@mnemonic, '_', $identitySuffix)"/>
            <xsl:value-of select="concat(
            'IF NOT EXISTS (SELECT * FROM sys.objects WHERE name = ', $Q, $knotName, $Q, ' and type LIKE ', $Q, '%U%', $Q, ')', $N,
            'CREATE TABLE [', $knotName, '] (', $N,
            $T, $knotIdentity, ' ', @identity, ' not null,', $N,
            $T, $knotName, ' ', @dataRange, ' not null unique,', $N,
            $metadataDefinition,
            $T, 'primary key (', $N,
            $T, $T, $knotIdentity, ' asc', $N,
            $T, ')', $N,
            ');', $N,
            'GO', $N
            )"/>
		</xsl:for-each>

        <!-- process all anchors -->
        <xsl:for-each select="anchor">
            <xsl:variable name="anchorMnemonic" select="@mnemonic"/>
            <xsl:variable name="anchorName" select="concat(@mnemonic, '_', @descriptor)"/>
            <xsl:variable name="anchorIdentity" select="concat(@mnemonic, '_', $identitySuffix)"/>
            <xsl:value-of select="concat(
            'IF NOT EXISTS (SELECT * FROM sys.objects WHERE name = ', $Q, $anchorName, $Q, ' and type LIKE ', $Q, '%U%', $Q, ')', $N,
            'CREATE TABLE [', $anchorName, '] (', $N,
            $T, $anchorIdentity, ' ', @identity, ' not null,', $N,
            $metadataDefinition,
            $T, 'primary key (', $N,
            $T, $T, $anchorIdentity, ' asc', $N,
            $T, ')', $N,
            ');', $N,
            'GO', $N
            )"/>
            <!-- process all attributes in the current anchor -->
            <xsl:for-each select="attribute">
                <xsl:variable name="attributeMnemonic" select="concat($anchorMnemonic, '_', @mnemonic)"/>
                <xsl:variable name="attributeName" select="concat($attributeMnemonic, '_', parent::*/@descriptor, '_', @descriptor)"/>
                <xsl:variable name="knotOrDataDefinition">
                    <xsl:choose>
                        <xsl:when test="key('knotLookup', @knotRange)">
                            <xsl:value-of select="concat($T, @knotRange, '_', $identitySuffix,' ', key('knotLookup', @knotRange)/@identity, ' not null foreign key references ', @knotRange, '_', key('knotLookup', @knotRange)/@descriptor, '(', @knotRange, '_', $identitySuffix,'),', $N)"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="concat($T, $attributeName, ' ', @dataRange, ' not null,', $N)"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="historizationDefinition">
                    <xsl:if test="@timeRange">
                        <xsl:value-of select="concat($T, $attributeMnemonic, '_', $historizationSuffix, ' ', @timeRange, ' not null,', $N)"/>
                    </xsl:if>
                </xsl:variable>
                <xsl:variable name="historizationKey">
                    <xsl:choose>
                        <xsl:when test="@timeRange">
                            <xsl:value-of select="concat(',', $N, $T, $T, $attributeMnemonic, '_', $historizationSuffix, ' desc', $N)"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$N"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:value-of select="concat(
                'IF NOT EXISTS (SELECT * FROM sys.objects WHERE name = ', $Q, $attributeName, $Q, ' and type LIKE ', $Q, '%U%', $Q, ')', $N,
                'CREATE TABLE [', $attributeName, '] (', $N,
                $T, $anchorIdentity, ' ', parent::*/@identity, ' not null foreign key references ', $anchorName, '(', $anchorIdentity, '),', $N,
                $knotOrDataDefinition,
                $historizationDefinition,
                $metadataDefinition,
                $T, 'primary key (', $N,
                $T, $T, $anchorIdentity, ' asc',
                $historizationKey,
                $T, ')', $N,
                ');', $N,
                'GO', $N
                )"/>
            </xsl:for-each>
            <!-- create the time perspectives -->
            <xsl:variable name="columnReferences">
                <xsl:for-each select="attribute">
                    <xsl:call-template name="columnReference">
                        <xsl:with-param name="attribute" select="."/>
                    </xsl:call-template>
                </xsl:for-each>
            </xsl:variable>
            <xsl:variable name="latestJoinConditions">
                <xsl:for-each select="attribute">
                    <xsl:call-template name="joinCondition">
                        <xsl:with-param name="attribute" select="."/>
                        <xsl:with-param name="timepoint"/>
                    </xsl:call-template>
                </xsl:for-each>
            </xsl:variable>
            <xsl:variable name="latestViewName" select="concat('l', $anchorName)"/>
            <xsl:value-of select="concat(
            'IF EXISTS (SELECT * FROM sys.objects WHERE name = ', $Q, $latestViewName, $Q, ' and type LIKE ', $Q, '%V%', $Q, ')', $N,
            'DROP VIEW [', $latestViewName, '];', $N,
            'GO', $N,
            'CREATE VIEW [', $latestViewName, '] AS', $N,
            'SELECT', $N,
            $T, '[', $anchorMnemonic, '].', $anchorIdentity,
            $columnReferences, $N,
            'FROM', $N,
            $T, $anchorName, ' [', $anchorMnemonic, ']',
            $latestJoinConditions, ';', $N,
            'GO', $N
            )"/>
            <xsl:variable name="point-in-timeJoinConditions">
                <xsl:for-each select="attribute">
                    <xsl:call-template name="joinCondition">
                        <xsl:with-param name="attribute" select="."/>
                        <xsl:with-param name="timepoint" select="'@timepoint'"/>
                    </xsl:call-template>
                </xsl:for-each>
            </xsl:variable>
            <xsl:variable name="point-in-timeFunctionName" select="concat('p', $anchorName)"/>
            <xsl:value-of select="concat(
            'IF EXISTS (SELECT * FROM sys.objects WHERE name = ', $Q, $point-in-timeFunctionName, $Q, ' and type LIKE ', $Q, '%F%', $Q, ')', $N,
            'DROP FUNCTION [', $point-in-timeFunctionName, '];', $N,
            'GO', $N,
            'CREATE FUNCTION [', $point-in-timeFunctionName, '] (@timepoint datetime)', $N,
            'RETURNS TABLE RETURN', $N,
            'SELECT', $N,
            $T, '[', $anchorMnemonic, '].', $anchorIdentity,
            $columnReferences, $N,
            'FROM', $N,
            $T, $anchorName, ' [', $anchorMnemonic, ']',
            $point-in-timeJoinConditions, ';', $N,
            'GO', $N
            )"/>
        </xsl:for-each>
    </xsl:template>
    <xsl:template name="joinCondition">
        <xsl:param name="attribute"/>
        <xsl:param name="timepoint"/>
        <xsl:variable name="anchor" select="$attribute/parent::anchor"/>
        <xsl:variable name="anchorMnemonic" select="$anchor/@mnemonic"/>
        <xsl:variable name="attributeMnemonic" select="concat($anchorMnemonic, '_', $attribute/@mnemonic)"/>
        <xsl:variable name="attributeName" select="concat($attributeMnemonic, '_', $anchor/@descriptor, '_', $attribute/@descriptor)"/>
        <xsl:variable name="anchorIdentity" select="concat($anchorMnemonic, '_', $identitySuffix)"/>
        <xsl:value-of select="concat($N, 'LEFT JOIN', $N, $T, $attributeName, ' [',  $attributeMnemonic, ']')"/>
        <xsl:value-of select="concat($N, 'ON', $N, $T, '[',  $attributeMnemonic, '].', $anchorIdentity, ' = [', $anchorMnemonic, '].', $anchorIdentity)"/>
        <xsl:if test="$attribute/@timeRange">
            <xsl:value-of select="concat($N, 'AND', $N, $T, '[', $attributeMnemonic, '].', $attributeMnemonic, '_', $historizationSuffix, ' = (')"/>
            <xsl:value-of select="concat($N, $T, $T, 'SELECT', $N, $T, $T, $T, 'max(sub.', $attributeMnemonic, '_', $historizationSuffix, ')')"/>
            <xsl:value-of select="concat($N, $T, $T, 'FROM', $N, $T, $T, $T, $attributeName, ' sub')"/>
            <xsl:value-of select="concat($N, $T, $T, 'WHERE', $N, $T, $T, $T, 'sub.', $anchorIdentity, ' = [', $anchorMnemonic, '].', $anchorIdentity)"/>
            <xsl:if test="normalize-space($timepoint)">
                <xsl:value-of select="concat($N, $T, $T, 'AND', $N, $T, $T, $T, 'sub.', $attributeMnemonic, '_', $historizationSuffix, ' &lt;= ', $timepoint)"/>
            </xsl:if>
            <xsl:value-of select="concat($N, $T, ')')"/>
        </xsl:if>
        <xsl:if test="key('knotLookup', $attribute/@knotRange)">
            <xsl:variable name="knotMnemonic" select="$attribute/@knotRange"/>
            <xsl:variable name="knotName" select="concat($knotMnemonic, '_', key('knotLookup', $attribute/@knotRange)/@descriptor)"/>
            <xsl:variable name="knotIdentity" select="concat($knotMnemonic, '_', $identitySuffix)"/>
            <xsl:value-of select="concat($N, 'LEFT JOIN', $N, $T, $knotName, ' [',  $knotMnemonic, ']')"/>
            <xsl:value-of select="concat($N, 'ON', $N, $T, '[',  $knotMnemonic, '].', $knotIdentity, ' = [', $attributeMnemonic, '].', $knotIdentity)"/>
        </xsl:if>
    </xsl:template>
    <xsl:template name="columnReference">
        <xsl:param name="attribute"/>
        <xsl:variable name="anchor" select="$attribute/parent::anchor"/>
        <xsl:variable name="anchorMnemonic" select="$anchor/@mnemonic"/>
        <xsl:variable name="attributeMnemonic" select="concat($anchorMnemonic, '_', $attribute/@mnemonic)"/>
        <xsl:variable name="attributeName" select="concat($attributeMnemonic, '_', $anchor/@descriptor, '_', $attribute/@descriptor)"/>
        <xsl:choose>
            <xsl:when test="key('knotLookup', @knotRange)">
                <xsl:variable name="knotMnemonic" select="$attribute/@knotRange"/>
                <xsl:variable name="knotName" select="concat($knotMnemonic, '_', key('knotLookup', $attribute/@knotRange)/@descriptor)"/>
                <xsl:variable name="knotIdentity" select="concat($knotMnemonic, '_', $identitySuffix)"/>
                <xsl:value-of select="concat(',', $N, $T, '[', $knotMnemonic, '].', $knotIdentity, ',', $N)"/>
                <xsl:value-of select="concat($T, '[', $knotMnemonic, '].', $knotName)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat(',', $N, $T, '[', $attributeMnemonic, '].', $attributeName)"/>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:if test="@timeRange">
            <xsl:value-of select="concat(',', $N, $T, '[', $attributeMnemonic, '].', $attributeMnemonic, '_', $historizationSuffix)"/>
        </xsl:if>
    </xsl:template>
    
    <xsl:template name="theOldStuff">

		<xsl:for-each select="anchor">
			<!-- create the difference function -->

			<xsl:text>IF EXISTS (SELECT * FROM sys.objects WHERE name = 'd</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_</xsl:text>
			<xsl:value-of select="@name"/>
			<xsl:text>' and type LIKE '%F%')&#10;</xsl:text>
			<xsl:text>DROP FUNCTION [d</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_</xsl:text>
			<xsl:value-of select="@name"/>
			<xsl:text>]; &#10;GO&#10;</xsl:text>
			<xsl:text>CREATE FUNCTION [d</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_</xsl:text>
			<xsl:value-of select="@name"/>
			<xsl:text>] (@intervalStart </xsl:text>
			<xsl:value-of select="'datetime'"/>
			<xsl:text>, @intervalEnd </xsl:text>
			<xsl:value-of select="'datetime'"/>
			<xsl:text>) &#10;RETURNS TABLE RETURN &#10;SELECT &#10;&#9;</xsl:text>
			<xsl:choose>
				<xsl:when test="attribute[@historized = 'true']">
					<xsl:text>[</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>]._inspectedDate, &#10;&#9;</xsl:text>
				</xsl:when>
				<xsl:otherwise>
					<xsl:text>NULL as _inspectedDate, &#10;&#9;</xsl:text>
				</xsl:otherwise>
			</xsl:choose>
			<xsl:text>[</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>].</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_ID</xsl:text>
			<xsl:if test="attribute">
				<xsl:text>, &#10;&#9;</xsl:text>
			</xsl:if>
			<xsl:for-each select="attribute">
				<xsl:choose>
					<xsl:when test="key('mnemonicToEntity', relation/@reference)">
						<xsl:text>[</xsl:text>
						<xsl:value-of select="relation/@reference"/>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="relation/@reference"/>
						<xsl:text>_</xsl:text>
						<xsl:value-of select="key('mnemonicToEntity', relation/@reference)/@name"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:text>[</xsl:text>
						<xsl:value-of select="@mnemonic"/>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="@mnemonic"/>
						<xsl:text>_</xsl:text>
						<xsl:value-of select="@name"/>
					</xsl:otherwise>
				</xsl:choose>
				<xsl:if test="@historized = 'true'">
					<xsl:text>, &#10;&#9;[</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>_FromDate</xsl:text>
				</xsl:if>
				<xsl:if test="not(position() = last())">
					<xsl:text>, &#10;&#9;</xsl:text>
				</xsl:if>
			</xsl:for-each>
			<xsl:text>&#10;FROM </xsl:text>
			<xsl:choose>
				<xsl:when test="attribute[@historized = 'true']">
					<xsl:text>(&#10;&#9;SELECT DISTINCT &#10;&#9;&#9;</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>_ID, &#10;&#9;&#9;_inspectedDate &#10;&#9;FROM (&#10;&#9;&#9;SELECT &#10;&#9;&#9;&#9;</xsl:text>
					<xsl:text>[s</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>_ID, &#10;&#9;&#9;&#9;</xsl:text>
					<xsl:for-each select="attribute[@historized = 'true']">
						<xsl:text>[s</xsl:text>
						<xsl:value-of select="@mnemonic"/>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="@mnemonic"/>
						<xsl:text>_FromDate</xsl:text>
						<xsl:if test="not(position() = last())">
							<xsl:text>, &#10;&#9;&#9;&#9;</xsl:text>
						</xsl:if>
					</xsl:for-each>
					<xsl:text>&#10;&#9;&#9;FROM &#10;&#9;&#9;&#9;</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>_</xsl:text>
					<xsl:value-of select="@name"/>
					<xsl:text> [s</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>]</xsl:text>
					<xsl:for-each select="attribute[@historized = 'true']">
						<xsl:text>&#10;&#9;&#9;LEFT JOIN &#10;&#9;&#9;&#9;</xsl:text>
						<xsl:value-of select="@mnemonic"/>
						<xsl:text>_</xsl:text>
						<xsl:value-of select="@name"/>
						<xsl:text> [s</xsl:text>
						<xsl:value-of select="@mnemonic"/>
						<xsl:text>]&#10;&#9;&#9;ON &#10;&#9;&#9;&#9;[s</xsl:text>
						<xsl:value-of select="@mnemonic"/>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="parent::anchor/@mnemonic"/>
						<xsl:text>_ID = [s</xsl:text>
						<xsl:value-of select="parent::anchor/@mnemonic"/>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="parent::anchor/@mnemonic"/>
						<xsl:text>_ID</xsl:text>
						<xsl:text>&#10;&#9;&#9;AND &#10;&#9;&#9;&#9;[s</xsl:text>
						<xsl:value-of select="@mnemonic"/>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="@mnemonic"/>
						<xsl:text>_FromDate between @intervalStart and @intervalEnd</xsl:text>
					</xsl:for-each>
					<xsl:text>&#10;&#9;) piv &#10;&#9;UNPIVOT (&#10;&#9;&#9;_inspectedDate for _historizationColumn in (&#10;&#9;&#9;&#9;</xsl:text>
					<xsl:for-each select="attribute[@historized = 'true']">
						<xsl:value-of select="@mnemonic"/>
						<xsl:text>_FromDate</xsl:text>
						<xsl:if test="not(position() = last())">
							<xsl:text>, &#10;&#9;&#9;&#9;</xsl:text>
						</xsl:if>
					</xsl:for-each>
					<xsl:text>&#10;&#9;&#9;) &#10;&#9;) unpiv &#10;) </xsl:text>
					<xsl:value-of select="@mnemonic"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:text>&#10;&#9;</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>_</xsl:text>
					<xsl:value-of select="@name"/>
					<xsl:text>&#32;[</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>]</xsl:text>
				</xsl:otherwise>
			</xsl:choose>
			<xsl:for-each select="attribute">
				<xsl:text>&#10;LEFT JOIN &#10;&#9;</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>_</xsl:text>
				<xsl:value-of select="@name"/>
				<xsl:text>&#32;[</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>]&#10;ON &#10;&#9;[</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>].</xsl:text>
				<xsl:value-of select="parent::anchor/@mnemonic"/>
				<xsl:text>_ID = [</xsl:text>
				<xsl:value-of select="parent::anchor/@mnemonic"/>
				<xsl:text>].</xsl:text>
				<xsl:value-of select="parent::anchor/@mnemonic"/>
				<xsl:text>_ID</xsl:text>
				<xsl:if test="@historized = 'true'">
					<xsl:text>&#10;AND &#10;&#9;</xsl:text>
					<xsl:text>[</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>_FromDate = (&#10;&#9;&#9;SELECT &#10;&#9;&#9;&#9;max(</xsl:text>
					<xsl:text>sub.</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>_FromDate) &#10;&#9;&#9;FROM &#10;&#9;&#9;&#9;</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>_</xsl:text>
					<xsl:value-of select="@name"/>
					<xsl:text> sub &#10;&#9;&#9;WHERE &#10;&#9;&#9;&#9;sub.</xsl:text>
					<xsl:value-of select="parent::anchor/@mnemonic"/>
					<xsl:text>_ID = [</xsl:text>
					<xsl:value-of select="parent::anchor/@mnemonic"/>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="parent::anchor/@mnemonic"/>
					<xsl:text>_ID &#10;&#9;&#9;AND &#10;&#9;&#9;&#9;sub.</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>_FromDate &lt;= [</xsl:text>
					<xsl:value-of select="parent::anchor/@mnemonic"/>
					<xsl:text>]._inspectedDate</xsl:text>
					<xsl:text>&#10;&#9;)</xsl:text>
				</xsl:if>
				<xsl:if test="relation">
					<xsl:text>&#10;LEFT JOIN &#10;&#9;</xsl:text>
					<xsl:value-of select="relation/@reference"/>
					<xsl:text>_</xsl:text>
					<xsl:value-of select="key('mnemonicToEntity', relation/@reference)/@name"/>
					<xsl:text>&#32;[</xsl:text>
					<xsl:value-of select="relation/@reference"/>
					<xsl:text>]&#10;ON &#10;&#9;[</xsl:text>
					<xsl:value-of select="relation/@reference"/>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="relation/@reference"/>
					<xsl:text>_ID = [</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="relation/@reference"/>
					<xsl:text>_ID</xsl:text>
				</xsl:if>
			</xsl:for-each>
			<xsl:text>;&#10;GO&#10;</xsl:text>

			<!-- create the extended difference function -->

			<xsl:text>IF EXISTS (SELECT * FROM sys.objects WHERE name = 'x</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_</xsl:text>
			<xsl:value-of select="@name"/>
			<xsl:text>' and type LIKE '%F%')&#10;</xsl:text>
			<xsl:text>DROP FUNCTION [x</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_</xsl:text>
			<xsl:value-of select="@name"/>
			<xsl:text>]; &#10;GO&#10;</xsl:text>
			<xsl:text>CREATE FUNCTION [x</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_</xsl:text>
			<xsl:value-of select="@name"/>
			<xsl:text>] (&#10;&#9;@intervalStart </xsl:text>
			<xsl:value-of select="'datetime'"/>
			<xsl:text>, &#10;&#9;@intervalEnd </xsl:text>
			<xsl:value-of select="'datetime'"/>
			<xsl:text>, &#10;&#9;@columns xml = '</xsl:text>
			<xsl:for-each select="attribute[@historized = 'true']">
				<xsl:text>&#10;&#9;&#9;&lt;col&gt;</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>_FromDate&lt;/col&gt;</xsl:text>
			</xsl:for-each>
			<xsl:text>&#10;&#9;'&#10;) &#10;RETURNS TABLE RETURN &#10;SELECT &#10;&#9;</xsl:text>
			<xsl:choose>
				<xsl:when test="attribute[@historized = 'true']">
					<xsl:text>[</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>]._inspectedDate, &#10;&#9;</xsl:text>
				</xsl:when>
				<xsl:otherwise>
					<xsl:text>NULL as _inspectedDate, &#10;&#9;</xsl:text>
				</xsl:otherwise>
			</xsl:choose>
			<xsl:text>[</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>].</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_ID</xsl:text>
			<xsl:if test="attribute">
				<xsl:text>, &#10;&#9;</xsl:text>
			</xsl:if>
			<xsl:for-each select="attribute">
				<xsl:choose>
					<xsl:when test="key('mnemonicToEntity', relation/@reference)">
						<xsl:text>[</xsl:text>
						<xsl:value-of select="relation/@reference"/>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="relation/@reference"/>
						<xsl:text>_</xsl:text>
						<xsl:value-of select="key('mnemonicToEntity', relation/@reference)/@name"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:text>[</xsl:text>
						<xsl:value-of select="@mnemonic"/>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="@mnemonic"/>
						<xsl:text>_</xsl:text>
						<xsl:value-of select="@name"/>
					</xsl:otherwise>
				</xsl:choose>
				<xsl:if test="@historized = 'true'">
					<xsl:text>, &#10;&#9;[</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>_FromDate</xsl:text>
				</xsl:if>
				<xsl:if test="not(position() = last())">
					<xsl:text>, &#10;&#9;</xsl:text>
				</xsl:if>
			</xsl:for-each>
			<xsl:text>&#10;FROM </xsl:text>
			<xsl:choose>
				<xsl:when test="attribute[@historized = 'true']">
					<xsl:text>(&#10;&#9;SELECT DISTINCT &#10;&#9;&#9;</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>_ID, &#10;&#9;&#9;_inspectedDate &#10;&#9;FROM (&#10;&#9;&#9;SELECT &#10;&#9;&#9;&#9;[s</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>_ID, &#10;&#9;&#9;&#9;</xsl:text>
					<xsl:for-each select="attribute[@historized = 'true']">
						<xsl:text>[s</xsl:text>
						<xsl:value-of select="@mnemonic"/>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="@mnemonic"/>
						<xsl:text>_FromDate</xsl:text>
						<xsl:if test="not(position() = last())">
							<xsl:text>, &#10;&#9;&#9;&#9;</xsl:text>
						</xsl:if>
					</xsl:for-each>
					<xsl:text>&#10;&#9;&#9;FROM &#10;&#9;&#9;&#9;</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>_</xsl:text>
					<xsl:value-of select="@name"/>
					<xsl:text> [s</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>]</xsl:text>
					<xsl:for-each select="attribute[@historized = 'true']">
						<xsl:text>&#10;&#9;&#9;LEFT JOIN &#10;&#9;&#9;&#9;</xsl:text>
						<xsl:value-of select="@mnemonic"/>
						<xsl:text>_</xsl:text>
						<xsl:value-of select="@name"/>
						<xsl:text> [s</xsl:text>
						<xsl:value-of select="@mnemonic"/>
						<xsl:text>]&#10;&#9;&#9;ON &#10;&#9;&#9;&#9;[s</xsl:text>
						<xsl:value-of select="@mnemonic"/>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="parent::anchor/@mnemonic"/>
						<xsl:text>_ID = [s</xsl:text>
						<xsl:value-of select="parent::anchor/@mnemonic"/>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="parent::anchor/@mnemonic"/>
						<xsl:text>_ID</xsl:text>
						<xsl:text>&#10;&#9;&#9;AND &#10;&#9;&#9;&#9;[s</xsl:text>
						<xsl:value-of select="@mnemonic"/>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="@mnemonic"/>
						<xsl:text>_FromDate between @intervalStart and @intervalEnd</xsl:text>
					</xsl:for-each>
					<xsl:text>&#10;&#9;) piv &#10;&#9;UNPIVOT (&#10;&#9;&#9;_inspectedDate for _historizationColumn in (&#10;&#9;&#9;&#9;</xsl:text>
					<xsl:for-each select="attribute[@historized = 'true']">
						<xsl:value-of select="@mnemonic"/>
						<xsl:text>_FromDate</xsl:text>
						<xsl:if test="not(position() = last())">
							<xsl:text>, &#10;&#9;&#9;&#9;</xsl:text>
						</xsl:if>
					</xsl:for-each>
					<xsl:text>&#10;&#9;&#9;) &#10;&#9;) unpiv &#10;&#9;WHERE &#10;&#9;&#9; _historizationColumn IN ((select name.value('.', 'varchar(255)') from @columns.nodes('/col') as T(name)))&#10;) </xsl:text>
					<xsl:value-of select="@mnemonic"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:text>&#10;&#9;</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>_</xsl:text>
					<xsl:value-of select="@name"/>
					<xsl:text>&#32;[</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>]</xsl:text>
				</xsl:otherwise>
			</xsl:choose>
			<xsl:for-each select="attribute">
				<xsl:text>&#10;LEFT JOIN &#10;&#9;</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>_</xsl:text>
				<xsl:value-of select="@name"/>
				<xsl:text>&#32;[</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>]&#10;ON &#10;&#9;[</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>].</xsl:text>
				<xsl:value-of select="parent::anchor/@mnemonic"/>
				<xsl:text>_ID = [</xsl:text>
				<xsl:value-of select="parent::anchor/@mnemonic"/>
				<xsl:text>].</xsl:text>
				<xsl:value-of select="parent::anchor/@mnemonic"/>
				<xsl:text>_ID</xsl:text>
				<xsl:if test="@historized = 'true'">
					<xsl:text>&#10;AND &#10;&#9;[</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>_FromDate = (&#10;&#9;&#9;SELECT &#10;&#9;&#9;&#9;max(</xsl:text>
					<xsl:text>sub.</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>_FromDate) &#10;&#9;&#9;FROM &#10;&#9;&#9;&#9;</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>_</xsl:text>
					<xsl:value-of select="@name"/>
					<xsl:text> sub &#10;&#9;&#9;WHERE &#10;&#9;&#9;&#9;sub.</xsl:text>
					<xsl:value-of select="parent::anchor/@mnemonic"/>
					<xsl:text>_ID = [</xsl:text>
					<xsl:value-of select="parent::anchor/@mnemonic"/>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="parent::anchor/@mnemonic"/>
					<xsl:text>_ID &#10;&#9;&#9;AND &#10;&#9;&#9;&#9;sub.</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>_FromDate &lt;= [</xsl:text>
					<xsl:value-of select="parent::anchor/@mnemonic"/>
					<xsl:text>]._inspectedDate</xsl:text>
					<xsl:text>&#10;&#9;)</xsl:text>
				</xsl:if>
				<xsl:if test="relation">
					<xsl:text>&#10;LEFT JOIN &#10;&#9;</xsl:text>
					<xsl:value-of select="relation/@reference"/>
					<xsl:text>_</xsl:text>
					<xsl:value-of select="key('mnemonicToEntity', relation/@reference)/@name"/>
					<xsl:text>&#32;[</xsl:text>
					<xsl:value-of select="relation/@reference"/>
					<xsl:text>]&#10;ON &#10;&#9;[</xsl:text>
					<xsl:value-of select="relation/@reference"/>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="relation/@reference"/>
					<xsl:text>_ID = [</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="relation/@reference"/>
					<xsl:text>_ID</xsl:text>
				</xsl:if>
			</xsl:for-each>
			<xsl:text>;&#10;GO&#10;</xsl:text>
		</xsl:for-each>

		<!-- process all ties -->

		<xsl:for-each select="tie">
			<xsl:text>IF NOT EXISTS (SELECT * FROM sys.objects WHERE name = '</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_</xsl:text>
			<xsl:value-of select="@name"/>
			<xsl:text>' and type LIKE '%U%')&#10;</xsl:text>
			<xsl:text>CREATE TABLE [</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_</xsl:text>
			<xsl:value-of select="@name"/>
			<xsl:text>] ( &#10;&#9;</xsl:text>
			<xsl:for-each select="relation">
				<xsl:value-of select="key('mnemonicToEntity', @reference)/@mnemonic"/>
				<xsl:text>_ID</xsl:text>
				<xsl:variable name="currentReference" select="@reference"/>
				<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
					<xsl:text>_</xsl:text>
					<xsl:value-of select="@ordinal"/>
				</xsl:if>
				<xsl:text>&#32;</xsl:text>
				<xsl:value-of select="key('mnemonicToEntity', @reference)/@idType"/>
				<xsl:text> not null, &#10;&#9;</xsl:text>
			</xsl:for-each>
			<xsl:if test="@historized = 'true'">
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>_FromDate </xsl:text>
				<xsl:value-of select="'datetime'"/>
				<xsl:text> not null, &#10;&#9;</xsl:text>
			</xsl:if>
			<xsl:value-of select="$metadata"/>
			<xsl:text>, &#10;&#9;PRIMARY KEY (</xsl:text>
			<xsl:for-each select="relation[@primary = 'true']">
				<xsl:value-of select="key('mnemonicToEntity', @reference)/@mnemonic"/>
				<xsl:text>_ID</xsl:text>
				<xsl:variable name="currentReference" select="@reference"/>
				<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
					<xsl:text>_</xsl:text>
					<xsl:value-of select="@ordinal"/>
				</xsl:if>
				<xsl:text> asc</xsl:text>
				<xsl:if test="not(position() = last())">
					<xsl:text>, </xsl:text>
				</xsl:if>
			</xsl:for-each>
			<xsl:if test="@historized = 'true'">
				<xsl:text>, </xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>_FromDate desc</xsl:text>
			</xsl:if>
			<xsl:text>) &#10;);&#10;GO&#10;</xsl:text>

			<!-- create the latest view -->

			<xsl:text>IF EXISTS (SELECT * FROM sys.objects WHERE name = 'l</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_</xsl:text>
			<xsl:value-of select="@name"/>
			<xsl:text>' and type LIKE '%V%')&#10;</xsl:text>
			<xsl:text>DROP VIEW [l</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_</xsl:text>
			<xsl:value-of select="@name"/>
			<xsl:text>]; &#10;GO&#10;</xsl:text>
			<xsl:text>CREATE VIEW [l</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_</xsl:text>
			<xsl:value-of select="@name"/>
			<xsl:text>] AS &#10;SELECT &#10;&#9;</xsl:text>
			<xsl:for-each select="relation">
				<xsl:choose>
					<xsl:when test="key('mnemonicToEntity', @reference)[local-name() = 'knot']">
						<xsl:text>[</xsl:text>
						<xsl:value-of select="key('mnemonicToEntity', @reference)/@mnemonic"/>
						<xsl:variable name="currentReference" select="@reference"/>
						<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
							<xsl:value-of select="@ordinal"/>
						</xsl:if>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="key('mnemonicToEntity', @reference)/@mnemonic"/>
						<xsl:text>_</xsl:text>
						<xsl:value-of select="key('mnemonicToEntity', @reference)/@name"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:text>[</xsl:text>
						<xsl:value-of select="parent::tie/@mnemonic"/>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="key('mnemonicToEntity', @reference)/@mnemonic"/>
						<xsl:text>_ID</xsl:text>
					</xsl:otherwise>
				</xsl:choose>
				<xsl:variable name="currentReference" select="@reference"/>
				<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
					<xsl:text>_</xsl:text>
					<xsl:value-of select="@ordinal"/>
				</xsl:if>
				<xsl:if test="not(position() = last())">
					<xsl:text>, &#10;&#9;</xsl:text>
				</xsl:if>
			</xsl:for-each>
			<xsl:if test="@historized = 'true'">
				<xsl:text>, &#10;&#9;[</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>].</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>_FromDate</xsl:text>
			</xsl:if>
			<xsl:text>&#10;FROM &#10;&#9;</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_</xsl:text>
			<xsl:value-of select="@name"/>
			<xsl:text>&#32;[</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>]</xsl:text>
			<xsl:variable name="tieMnemonic" select="@mnemonic"/>
			<xsl:for-each select="relation">
				<xsl:variable name="knot" select="key('mnemonicToEntity', @reference)[local-name() = 'knot']"/>
				<xsl:if test="$knot">					
					<xsl:text>&#10;LEFT JOIN &#10;&#9;</xsl:text>
					<xsl:value-of select="$knot/@mnemonic"/>
					<xsl:text>_</xsl:text>
					<xsl:value-of select="$knot/@name"/>
					<xsl:text>&#32;[</xsl:text>
					<xsl:value-of select="$knot/@mnemonic"/>
					<xsl:variable name="currentReference" select="@reference"/>
					<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
						<xsl:value-of select="@ordinal"/>
					</xsl:if>
					<xsl:text>]&#10;ON &#10;&#9;[</xsl:text>
					<xsl:value-of select="$knot/@mnemonic"/>
					<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
						<xsl:value-of select="@ordinal"/>
					</xsl:if>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="$knot/@mnemonic"/>
					<xsl:text>_ID = [</xsl:text>
					<xsl:value-of select="$tieMnemonic"/>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="$knot/@mnemonic"/>
					<xsl:text>_ID</xsl:text>
					<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
						<xsl:text>_</xsl:text>
						<xsl:value-of select="@ordinal"/>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
			<xsl:if test="@historized = 'true'">
				<xsl:text>&#10;WHERE &#10;&#9;[</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>].</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>_FromDate = (&#10;&#9;&#9;SELECT &#10;&#9;&#9;&#9;max(</xsl:text>
				<xsl:text>sub.</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>_FromDate) &#10;&#9;&#9;FROM &#10;&#9;&#9;&#9;</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>_</xsl:text>
				<xsl:value-of select="@name"/>
				<xsl:text> sub &#10;&#9;&#9;WHERE </xsl:text>
				<xsl:for-each select="relation[@primary = 'true']">
					<xsl:text>&#10;&#9;&#9;&#9;sub.</xsl:text>
					<xsl:value-of select="@reference"/>
					<xsl:text>_ID</xsl:text>
					<xsl:variable name="currentReference" select="@reference"/>
					<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
						<xsl:text>_</xsl:text>
						<xsl:value-of select="@ordinal"/>
					</xsl:if>
					<xsl:text> = [</xsl:text>
					<xsl:value-of select="parent::tie/@mnemonic"/>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="@reference"/>
					<xsl:text>_ID</xsl:text>
					<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
						<xsl:text>_</xsl:text>
						<xsl:value-of select="@ordinal"/>
					</xsl:if>
					<xsl:if test="not(position() = last())">
						<xsl:text>&#10;&#9;&#9;AND </xsl:text>
					</xsl:if>
				</xsl:for-each>
				<xsl:text>&#10;&#9;)</xsl:text>
			</xsl:if>
			<xsl:text>;&#10;GO&#10;</xsl:text>

			<!-- create the point-in-time function -->

			<xsl:text>IF EXISTS (SELECT * FROM sys.objects WHERE name = 'p</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_</xsl:text>
			<xsl:value-of select="@name"/>
			<xsl:text>' and type LIKE '%F%')&#10;</xsl:text>
			<xsl:text>DROP FUNCTION [p</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_</xsl:text>
			<xsl:value-of select="@name"/>
			<xsl:text>]; &#10;GO&#10;</xsl:text>
			<xsl:text>CREATE FUNCTION [p</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_</xsl:text>
			<xsl:value-of select="@name"/>
			<xsl:text>] (@timepoint </xsl:text>
			<xsl:value-of select="'datetime'"/>
			<xsl:text>) &#10;RETURNS TABLE RETURN &#10;SELECT &#10;&#9;</xsl:text>
			<xsl:for-each select="relation">
				<xsl:choose>
					<xsl:when test="key('mnemonicToEntity', @reference)[local-name() = 'knot']">
						<xsl:text>[</xsl:text>
						<xsl:value-of select="key('mnemonicToEntity', @reference)/@mnemonic"/>
						<xsl:variable name="currentReference" select="@reference"/>
						<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
							<xsl:value-of select="@ordinal"/>
						</xsl:if>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="key('mnemonicToEntity', @reference)/@mnemonic"/>
						<xsl:text>_</xsl:text>
						<xsl:value-of select="key('mnemonicToEntity', @reference)/@name"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:text>[</xsl:text>
						<xsl:value-of select="parent::tie/@mnemonic"/>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="key('mnemonicToEntity', @reference)/@mnemonic"/>
						<xsl:text>_ID</xsl:text>
					</xsl:otherwise>
				</xsl:choose>
				<xsl:variable name="currentReference" select="@reference"/>
				<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
					<xsl:text>_</xsl:text>
					<xsl:value-of select="@ordinal"/>
				</xsl:if>
				<xsl:if test="not(position() = last())">
					<xsl:text>, &#10;&#9;</xsl:text>
				</xsl:if>
			</xsl:for-each>
			<xsl:if test="@historized = 'true'">
				<xsl:text>, &#10;&#9;[</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>].</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>_FromDate</xsl:text>
			</xsl:if>
			<xsl:text>&#10;FROM &#10;&#9;</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_</xsl:text>
			<xsl:value-of select="@name"/>
			<xsl:text>&#32;[</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>]</xsl:text>
			<xsl:for-each select="relation">
				<xsl:variable name="knot" select="key('mnemonicToEntity', @reference)[local-name() = 'knot']"/>
				<xsl:if test="$knot">
					<xsl:text>&#10;LEFT JOIN &#10;&#9;</xsl:text>
					<xsl:value-of select="$knot/@mnemonic"/>
					<xsl:text>_</xsl:text>
					<xsl:value-of select="$knot/@name"/>
					<xsl:text>&#32;[</xsl:text>
					<xsl:value-of select="$knot/@mnemonic"/>
					<xsl:variable name="currentReference" select="@reference"/>
					<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
						<xsl:value-of select="@ordinal"/>
					</xsl:if>
					<xsl:text>]&#10;ON &#10;&#9;[</xsl:text>
					<xsl:value-of select="$knot/@mnemonic"/>
					<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
						<xsl:value-of select="@ordinal"/>
					</xsl:if>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="$knot/@mnemonic"/>
					<xsl:text>_ID = [</xsl:text>
					<xsl:value-of select="$tieMnemonic"/>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="$knot/@mnemonic"/>
					<xsl:text>_ID</xsl:text>
					<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
						<xsl:text>_</xsl:text>
						<xsl:value-of select="@ordinal"/>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
			<xsl:if test="@historized = 'true'">
				<xsl:text>&#10;WHERE &#10;&#9;[</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>].</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>_FromDate = (&#10;&#9;&#9;SELECT &#10;&#9;&#9;&#9;max(</xsl:text>
				<xsl:text>sub.</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>_FromDate) &#10;&#9;&#9;FROM &#10;&#9;&#9;&#9;</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>_</xsl:text>
				<xsl:value-of select="@name"/>
				<xsl:text> sub &#10;&#9;&#9;WHERE </xsl:text>
				<xsl:for-each select="relation[@primary = 'true']">
					<xsl:text>&#10;&#9;&#9;&#9;sub.</xsl:text>
					<xsl:value-of select="@reference"/>
					<xsl:text>_ID</xsl:text>
					<xsl:variable name="currentReference" select="@reference"/>
					<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
						<xsl:text>_</xsl:text>
						<xsl:value-of select="@ordinal"/>
					</xsl:if>
					<xsl:text> = [</xsl:text>
					<xsl:value-of select="parent::tie/@mnemonic"/>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="@reference"/>
					<xsl:text>_ID</xsl:text>
					<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
						<xsl:text>_</xsl:text>
						<xsl:value-of select="@ordinal"/>
					</xsl:if>
					<xsl:if test="not(position() = last())">
						<xsl:text>&#10;&#9;&#9;AND </xsl:text>
					</xsl:if>
				</xsl:for-each>
				<xsl:text>&#10;&#9;&#9;AND &#10;&#9;&#9;&#9;sub.</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>_FromDate &lt;= @timepoint</xsl:text>
				<xsl:text>&#10;&#9;)</xsl:text>
			</xsl:if>
			<xsl:choose>
				<xsl:when test="relation[not(@primary = 'true')] and @historized = 'true'">
					<xsl:text>&#10;AND &#10;&#9;</xsl:text>
				</xsl:when>
				<xsl:when test="relation[not(@primary = 'true')] and not(@historized = 'true')">
					<xsl:text>&#10;WHERE &#10;&#9;</xsl:text>
				</xsl:when>
			</xsl:choose>
			<xsl:for-each select="relation[not(@primary = 'true')]">
				<xsl:choose>
					<xsl:when test="key('mnemonicToEntity', @reference)[local-name() = 'knot']">
						<xsl:text>[</xsl:text>
						<xsl:value-of select="@reference"/>
						<xsl:variable name="currentReference" select="@reference"/>
						<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
							<xsl:value-of select="@ordinal"/>
						</xsl:if>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="@reference"/>
						<xsl:text>_</xsl:text>
						<xsl:value-of select="key('mnemonicToEntity', @reference)/@name"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:text>[</xsl:text>
						<xsl:value-of select="$tieMnemonic"/>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="@reference"/>
						<xsl:text>_ID</xsl:text>
						<xsl:variable name="currentReference" select="@reference"/>
						<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
							<xsl:text>_</xsl:text>
							<xsl:value-of select="@ordinal"/>
						</xsl:if>
					</xsl:otherwise>
				</xsl:choose>
				<xsl:text> is not null</xsl:text>
				<xsl:if test="not(position() = last())">
					<xsl:text>&#10;OR &#10;&#9;</xsl:text>
				</xsl:if>
			</xsl:for-each>
			<xsl:text>;&#10;GO&#10;</xsl:text>

			<!-- create the difference function -->

			<xsl:text>IF EXISTS (SELECT * FROM sys.objects WHERE name = 'd</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_</xsl:text>
			<xsl:value-of select="@name"/>
			<xsl:text>' and type LIKE '%F%')&#10;</xsl:text>
			<xsl:text>DROP FUNCTION [d</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_</xsl:text>
			<xsl:value-of select="@name"/>
			<xsl:text>]; &#10;GO&#10;</xsl:text>
			<xsl:text>CREATE FUNCTION [d</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_</xsl:text>
			<xsl:value-of select="@name"/>
			<xsl:text>] (@intervalStart </xsl:text>
			<xsl:value-of select="'datetime'"/>
			<xsl:text>, @intervalEnd </xsl:text>
			<xsl:value-of select="'datetime'"/>
			<xsl:text>) &#10;RETURNS TABLE RETURN &#10;SELECT &#10;&#9;</xsl:text>
			<xsl:choose>
				<xsl:when test="@historized = 'true'">
					<xsl:text>[</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="@mnemonic"/>
					<xsl:text>_FromDate as _inspectedDate, &#10;&#9;</xsl:text>
				</xsl:when>
				<xsl:otherwise>
					<xsl:text>NULL as _inspectedDate, &#10;&#9;</xsl:text>
				</xsl:otherwise>
			</xsl:choose>
			<xsl:for-each select="relation">
				<xsl:choose>
					<xsl:when test="key('mnemonicToEntity', @reference)[local-name() = 'knot']">
						<xsl:text>[</xsl:text>
						<xsl:value-of select="key('mnemonicToEntity', @reference)/@mnemonic"/>
						<xsl:variable name="currentReference" select="@reference"/>
						<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
							<xsl:value-of select="@ordinal"/>
						</xsl:if>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="key('mnemonicToEntity', @reference)/@mnemonic"/>
						<xsl:text>_</xsl:text>
						<xsl:value-of select="key('mnemonicToEntity', @reference)/@name"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:text>[</xsl:text>
						<xsl:value-of select="parent::tie/@mnemonic"/>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="key('mnemonicToEntity', @reference)/@mnemonic"/>
						<xsl:text>_ID</xsl:text>
					</xsl:otherwise>
				</xsl:choose>
				<xsl:variable name="currentReference" select="@reference"/>
				<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
					<xsl:text>_</xsl:text>
					<xsl:value-of select="@ordinal"/>
				</xsl:if>
				<xsl:if test="not(position() = last())">
					<xsl:text>, &#10;&#9;</xsl:text>
				</xsl:if>
			</xsl:for-each>
			<xsl:if test="@historized = 'true'">
				<xsl:text>, &#10;&#9;[</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>].</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>_FromDate</xsl:text>
			</xsl:if>
			<xsl:text>&#10;FROM &#10;&#9;</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>_</xsl:text>
			<xsl:value-of select="@name"/>
			<xsl:text>&#32;[</xsl:text>
			<xsl:value-of select="@mnemonic"/>
			<xsl:text>]</xsl:text>
			<xsl:for-each select="relation">
				<xsl:variable name="knot" select="key('mnemonicToEntity', @reference)[local-name() = 'knot']"/>
				<xsl:if test="$knot">
					<xsl:text>&#10;LEFT JOIN &#10;&#9;</xsl:text>
					<xsl:value-of select="$knot/@mnemonic"/>
					<xsl:text>_</xsl:text>
					<xsl:value-of select="$knot/@name"/>
					<xsl:text>&#32;[</xsl:text>
					<xsl:value-of select="$knot/@mnemonic"/>
					<xsl:variable name="currentReference" select="@reference"/>
					<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
						<xsl:value-of select="@ordinal"/>
					</xsl:if>
					<xsl:text>]&#10;ON &#10;&#9;[</xsl:text>
					<xsl:value-of select="$knot/@mnemonic"/>
					<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
						<xsl:value-of select="@ordinal"/>
					</xsl:if>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="$knot/@mnemonic"/>
					<xsl:text>_ID = [</xsl:text>
					<xsl:value-of select="$tieMnemonic"/>
					<xsl:text>].</xsl:text>
					<xsl:value-of select="$knot/@mnemonic"/>
					<xsl:text>_ID</xsl:text>
					<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
						<xsl:text>_</xsl:text>
						<xsl:value-of select="@ordinal"/>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
			<xsl:if test="@historized = 'true'">
				<xsl:text>&#10;WHERE &#10;&#9;[</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>].</xsl:text>
				<xsl:value-of select="@mnemonic"/>
				<xsl:text>_FromDate between @intervalStart and @intervalEnd</xsl:text>
			</xsl:if>
			<xsl:choose>
				<xsl:when test="relation[not(@primary = 'true')] and @historized = 'true'">
					<xsl:text>&#10;AND &#10;&#9;</xsl:text>
				</xsl:when>
				<xsl:when test="relation[not(@primary = 'true')] and not(@historized = 'true')">
					<xsl:text>&#10;WHERE &#10;&#9;</xsl:text>
				</xsl:when>
			</xsl:choose>
			<xsl:for-each select="relation[not(@primary = 'true')]">
				<xsl:choose>
					<xsl:when test="key('mnemonicToEntity', @reference)[local-name() = 'knot']">
						<xsl:text>[</xsl:text>
						<xsl:value-of select="@reference"/>
						<xsl:variable name="currentReference" select="@reference"/>
						<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
							<xsl:value-of select="@ordinal"/>
						</xsl:if>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="@reference"/>
						<xsl:text>_</xsl:text>
						<xsl:value-of select="key('mnemonicToEntity', @reference)/@name"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:text>[</xsl:text>
						<xsl:value-of select="$tieMnemonic"/>
						<xsl:text>].</xsl:text>
						<xsl:value-of select="@reference"/>
						<xsl:text>_ID</xsl:text>
						<xsl:variable name="currentReference" select="@reference"/>
						<xsl:if test="count(../relation[@reference = $currentReference]) > 1">
							<xsl:text>_</xsl:text>
							<xsl:value-of select="@ordinal"/>
						</xsl:if>
					</xsl:otherwise>
				</xsl:choose>
				<xsl:text> is not null</xsl:text>
				<xsl:if test="not(position() = last())">
					<xsl:text>&#10;OR &#10;&#9;</xsl:text>
				</xsl:if>
			</xsl:for-each>
			<xsl:text>;&#10;GO&#10;</xsl:text>
		</xsl:for-each>
	</xsl:template>
</xsl:stylesheet>