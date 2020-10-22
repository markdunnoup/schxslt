<!-- Compile preprocessed Schematron to validation stylesheet -->
<xsl:transform version="2.0"
               xmlns="http://www.w3.org/1999/XSL/TransformAlias"
               xmlns:sch="http://purl.oclc.org/dsdl/schematron"
               xmlns:error="https://doi.org/10.5281/zenodo.1495494#error"
               xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
               xmlns:schxslt-api="https://doi.org/10.5281/zenodo.1495494#api"
               xmlns:schxslt="https://doi.org/10.5281/zenodo.1495494"
               xmlns:xs="http://www.w3.org/2001/XMLSchema"
               xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:import href="api-2.0.xsl"/>

  <doc xmlns="http://www.oxygenxml.com/ns/doc/xsl">
    <desc>
      <p>Compile preprocessed Schematron to validation stylesheet</p>
    </desc>
    <param name="phase">Validation phase</param>
  </doc>

  <xsl:namespace-alias stylesheet-prefix="#default" result-prefix="xsl"/>
  <xsl:output indent="yes"/>

  <xsl:include href="functions.xsl"/>
  <xsl:include href="templates.xsl"/>
  <xsl:include href="../version.xsl"/>

  <xsl:param name="phase" as="xs:string">#DEFAULT</xsl:param>
  <xsl:param name="schxslt.compile.typed-variables" as="xs:boolean" select="true()"/>

  <xsl:template match="/sch:schema">
    <xsl:call-template name="schxslt:compile">
      <xsl:with-param name="schematron" as="element(sch:schema)" select="."/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="schxslt:compile">
    <xsl:param name="schematron" as="element(sch:schema)" required="yes"/>

    <xsl:variable name="xslt-version" as="xs:string" select="schxslt:xslt-version($schematron)"/>
    <xsl:variable name="effective-phase" select="schxslt:effective-phase($schematron, $phase)" as="xs:string"/>
    <xsl:variable name="active-patterns" select="schxslt:active-patterns($schematron, $effective-phase)" as="element(sch:pattern)+"/>

    <xsl:variable name="validation-stylesheet-body" as="element(xsl:template)+">
      <xsl:call-template name="schxslt:validation-stylesheet-body">
        <xsl:with-param name="patterns" as="element(sch:pattern)+" select="$active-patterns"/>
        <xsl:with-param name="typed-variables" as="xs:boolean" select="$schxslt.compile.typed-variables"/>
        <xsl:with-param name="xslt-version" as="xs:string" tunnel="yes" select="$xslt-version"/>
        <xsl:with-param name="location-function" as="xs:string" tunnel="yes">
          <xsl:choose>
            <xsl:when test="$xslt-version eq '3.0' and empty($schematron/xsl:function[schxslt:is-location-function(.)])">
              <xsl:text>path</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>schxslt:location</xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:variable>

    <xsl:variable name="version" as="element(rdf:Description)">
      <xsl:call-template name="schxslt:version">
        <xsl:with-param name="xslt-version" as="xs:string" tunnel="yes" select="$xslt-version"/>
      </xsl:call-template>
    </xsl:variable>

    <transform version="{$xslt-version}">
      <xsl:for-each select="$schematron/sch:ns">
        <xsl:namespace name="{@prefix}" select="@uri"/>
      </xsl:for-each>
      <xsl:sequence select="$schematron/@xml:base"/>

      <xsl:sequence select="$version"/>

      <xsl:call-template name="schxslt-api:validation-stylesheet-body-top-hook">
        <xsl:with-param name="schema" as="element(sch:schema)" select="$schematron"/>
        <xsl:with-param name="xslt-version" as="xs:string" tunnel="yes" select="$xslt-version"/>
      </xsl:call-template>

      <output indent="yes"/>

      <xsl:sequence select="$schematron/xsl:key[not(preceding-sibling::sch:pattern)]"/>
      <xsl:sequence select="$schematron/xsl:function[not(preceding-sibling::sch:pattern)]"/>

      <!-- See https://github.com/dmj/schxslt/issues/25 -->
      <xsl:variable name="global-bindings" as="element(sch:let)*" select="($schematron/sch:let, $schematron/sch:phase[@id eq $effective-phase]/sch:let, $active-patterns/sch:let)"/>
      <xsl:call-template name="schxslt:check-multiply-defined">
        <xsl:with-param name="bindings" select="$global-bindings" as="element(sch:let)*"/>
      </xsl:call-template>

      <xsl:call-template name="schxslt:let-param">
        <xsl:with-param name="bindings" select="$schematron/sch:let"/>
        <xsl:with-param name="typed-variables" as="xs:boolean" select="$schxslt.compile.typed-variables"/>
      </xsl:call-template>

      <xsl:call-template name="schxslt:let-variable">
        <xsl:with-param name="bindings" select="($schematron/sch:phase[@id eq $effective-phase]/sch:let, $active-patterns/sch:let)"/>
        <xsl:with-param name="typed-variables" as="xs:boolean" select="$schxslt.compile.typed-variables"/>
      </xsl:call-template>

      <template match="/">
        <xsl:sequence select="$schematron/sch:phase[@id eq $effective-phase]/@xml:base"/>

        <xsl:call-template name="schxslt:let-variable">
          <xsl:with-param name="bindings" select="$schematron/sch:phase[@id eq $effective-phase]/sch:let"/>
          <xsl:with-param name="typed-variables" as="xs:boolean" select="$schxslt.compile.typed-variables"/>
        </xsl:call-template>

        <variable name="metadata" as="element()?">
          <xsl:call-template name="schxslt-api:metadata">
            <xsl:with-param name="schema" as="element(sch:schema)" select="$schematron"/>
            <xsl:with-param name="source" as="element(rdf:Description)" select="$version"/>
            <xsl:with-param name="xslt-version" as="xs:string" tunnel="yes" select="$xslt-version"/>
          </xsl:call-template>
        </variable>

        <variable name="report" as="element(schxslt:report)">
          <schxslt:report>
            <xsl:for-each select="$validation-stylesheet-body/@name">
              <call-template name="{.}"/>
            </xsl:for-each>
          </schxslt:report>
        </variable>

        <!-- Unwrap the intermediary report -->
        <variable name="schxslt:report" as="node()*">
          <sequence select="$metadata"/>
          <for-each select="$report/schxslt:pattern">
            <sequence select="node()"/>
            <sequence select="$report/schxslt:rule[@pattern = current()/@id]/node()"/>
          </for-each>
        </variable>

        <xsl:call-template name="schxslt-api:report">
          <xsl:with-param name="schema" as="element(sch:schema)" select="$schematron"/>
          <xsl:with-param name="phase" as="xs:string" select="$effective-phase"/>
          <xsl:with-param name="xslt-version" as="xs:string" tunnel="yes" select="$xslt-version"/>
        </xsl:call-template>

      </template>

      <template match="text() | @*" mode="#all" priority="-10"/>
      <template match="*" mode="#all" priority="-10">
        <apply-templates mode="#current" select="@* | node()"/>
      </template>

      <xsl:sequence select="$validation-stylesheet-body"/>

      <xsl:if test="$xslt-version eq '2.0' and empty($schematron/xsl:function[schxslt:is-location-function(.)])">
        <function name="schxslt:location" as="xs:string">
          <param name="node" as="node()"/>
          <variable name="segments" as="xs:string*">
            <for-each select="($node/ancestor-or-self::node())">
              <variable name="position">
                <number level="single"/>
              </variable>
              <choose>
                <when test=". instance of element()">
                  <value-of select="concat('Q{{', namespace-uri(.), '}}', local-name(.), '[', $position, ']')"/>
                </when>
                <when test=". instance of attribute()">
                  <value-of select="concat('@Q{{', namespace-uri(.), '}}', local-name(.))"/>
                </when>
                <when test=". instance of processing-instruction()">
                  <value-of select="concat('processing-instruction(&quot;', name(.), '&quot;)[', $position, ']')"/>
                </when>
                <when test=". instance of comment()">
                  <value-of select="concat('comment()[', $position, ']')"/>
                </when>
                <when test=". instance of text()">
                  <value-of select="concat('text()[', $position, ']')"/>
                </when>
                <otherwise/>
              </choose>
            </for-each>
          </variable>

          <value-of select="concat('/', string-join($segments, '/'))"/>
        </function>
      </xsl:if>

      <xsl:call-template name="schxslt-api:validation-stylesheet-body-bottom-hook">
        <xsl:with-param name="schema" as="element(sch:schema)" select="$schematron"/>
        <xsl:with-param name="xslt-version" as="xs:string" tunnel="yes" select="$xslt-version"/>
      </xsl:call-template>

    </transform>

  </xsl:template>

  <doc xmlns="http://www.oxygenxml.com/ns/doc/xsl">
    <desc>
      <p>Return rule template</p>
    </desc>
    <param name="mode">Template mode</param>
  </doc>
  <xsl:template match="sch:rule" mode="schxslt:compile">
    <xsl:param name="mode" as="xs:string" required="yes"/>
    <xsl:param name="typed-variables" as="xs:boolean" required="yes"/>

    <xsl:call-template name="schxslt:check-multiply-defined">
      <xsl:with-param name="bindings" select="sch:let" as="element(sch:let)*"/>
    </xsl:call-template>

    <template match="{@context}" priority="{count(following::sch:rule)}" mode="{$mode}">
      <xsl:sequence select="(@xml:base, ../@xml:base)"/>

      <!-- Check if a context node was already matched by a rule of the current pattern. -->
      <param name="schxslt:patterns-matched" as="xs:string*"/>

      <xsl:call-template name="schxslt:let-variable">
        <xsl:with-param name="bindings" as="element(sch:let)*" select="sch:let"/>
        <xsl:with-param name="typed-variables" as="xs:boolean" select="$typed-variables"/>
      </xsl:call-template>

      <schxslt:rule pattern="{generate-id(..)}">
        <choose>
          <when test="$schxslt:patterns-matched[. = '{generate-id(..)}']">
            <xsl:call-template name="schxslt-api:suppressed-rule">
              <xsl:with-param name="rule" as="element(sch:rule)" select="."/>
            </xsl:call-template>
          </when>
          <otherwise>
            <xsl:call-template name="schxslt-api:fired-rule">
              <xsl:with-param name="rule" as="element(sch:rule)" select="."/>
            </xsl:call-template>
            <xsl:apply-templates select="sch:assert | sch:report" mode="schxslt:compile"/>
          </otherwise>
        </choose>
      </schxslt:rule>

      <next-match>
        <with-param name="schxslt:patterns-matched" as="xs:string*" select="($schxslt:patterns-matched, '{generate-id(..)}')"/>
      </next-match>
    </template>

  </xsl:template>

  <doc xmlns="http://www.oxygenxml.com/ns/doc/xsl">
    <desc>
      <p>Return body of validation stylesheet</p>
    </desc>
    <param name="patterns">Sequence of active patterns</param>
  </doc>
  <xsl:template name="schxslt:validation-stylesheet-body">
    <xsl:param name="patterns" as="element(sch:pattern)+"/>
    <xsl:param name="typed-variables" as="xs:boolean" required="yes"/>

    <xsl:for-each-group select="$patterns" group-by="string-join((base-uri(.), @documents), '~')">
      <xsl:variable name="mode" as="xs:string" select="generate-id()"/>
      <xsl:variable name="baseUri" as="xs:anyURI" select="base-uri(.)"/>

      <template name="{$mode}">
        <xsl:sequence select="@xml:base"/>

        <xsl:choose>
          <xsl:when test="@documents">
            <for-each select="{@documents}">
              <variable name="document" as="item()" select="document(resolve-uri(., '{$baseUri}'))"/>
              <xsl:for-each select="current-group()">
                <schxslt:pattern id="{generate-id()}">
                  <if test="exists(base-uri($document))">
                    <attribute name="documents" select="base-uri($document)"/>
                  </if>
                  <for-each select="$document">
                    <xsl:call-template name="schxslt-api:active-pattern">
                      <xsl:with-param name="pattern" as="element(sch:pattern)" select="."/>
                    </xsl:call-template>
                  </for-each>
                  <apply-templates mode="{$mode}" select="$document"/>
                </schxslt:pattern>
              </xsl:for-each>
            </for-each>
          </xsl:when>
          <xsl:otherwise>
            <xsl:for-each select="current-group()">
              <schxslt:pattern id="{generate-id()}">
                <if test="exists(base-uri(/))">
                  <attribute name="documents" select="base-uri(/)"/>
                </if>
                <for-each select="/">
                  <xsl:call-template name="schxslt-api:active-pattern">
                    <xsl:with-param name="pattern" as="element(sch:pattern)" select="."/>
                  </xsl:call-template>
                </for-each>
                <apply-templates mode="{$mode}" select="/"/>
              </schxslt:pattern>
            </xsl:for-each>
          </xsl:otherwise>
        </xsl:choose>

      </template>

      <xsl:apply-templates select="current-group()/sch:rule" mode="schxslt:compile">
        <xsl:with-param name="mode" as="xs:string" select="$mode"/>
        <xsl:with-param name="typed-variables" as="xs:boolean" select="$typed-variables"/>
      </xsl:apply-templates>

    </xsl:for-each-group>

  </xsl:template>

</xsl:transform>
