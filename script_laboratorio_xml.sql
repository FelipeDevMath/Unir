-- PASO 1: Consulta SQL/XML para la extracción de datos relacionales -- Combina las tablas DEPARTMENTS y EMPLOYEES produciendo una salida XML estructurada.  

SELECT XMLELEMENT("departamentos", 
		XMLAGG( 
			XMLELEMENT("departamento", 
				XMLATTRIBUTES(d.department\_id AS "id"), 
				XMLFOREST(d.department\_name AS "nombre"), 
				XMLELEMENT("empleados", 
					(SELECT XMLAGG( 
							XMLELEMENT("empleado", 
								XMLATTRIBUTES(e.employee\_id AS "id"), 
								XMLFOREST(e.first\_name AS "nombre", e.last\_name AS "apellido", e.email AS "email") 
								) 
							) 
					FROM employees e 
					WHERE e.department\_id = d.department\_id) 
				) 
			) 
		) 
	).getClobVal() AS xml\_resultado 
FROM departments d;

-- PASO 2: Registro del Esquema XML (XSD) en el catálogo de Oracle -- Registrar la estructura lógica mediante el paquete DBMS_XMLSCHEMA

BEGIN
  DBMS_XMLSCHEMA.registerSchema(
    schemaurl => 'http://localhost/departamentos.xsd',
    schemadoc => '<?xml version="1.0" encoding="UTF-8"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:element name="departamentos">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="departamento" maxOccurs="unbounded" minOccurs="0">
          <xs:complexType>
            <xs:sequence>
              <xs:element type="xs:string" name="nombre"/>
              <xs:element name="empleados" minOccurs="0">
                <xs:complexType>
                  <xs:sequence>
                    <xs:element name="empleado" maxOccurs="unbounded" minOccurs="0">
                      <xs:complexType>
                        <xs:sequence>
                          <xs:element type="xs:string" name="nombre"/>
                          <xs:element type="xs:string" name="apellido"/>
                          <xs:element type="xs:string" name="email"/>
                        </xs:sequence>
                        <xs:attribute type="xs:integer" name="id" use="required"/>
                      </xs:complexType>
                    </xs:element>
                  </xs:sequence>
                </xs:complexType>
              </xs:element>
            </xs:sequence>
            <xs:attribute type="xs:integer" name="id" use="required"/>
          </xs:complexType>
        </xs:element>
      </xs:sequence>
    </xs:complexType>
  </xs:element>
</xs:schema>',
    local     => TRUE,
    genTypes  => FALSE,
    genTables => FALSE
  );
END;


-- PASO 3: Creación de la tabla fuertemente tipada basada en el Esquema XSD

CREATE TABLE tabla_departamentos_xml OF XMLTYPE
  XMLSCHEMA "http://localhost/departamentos.xsd"
  ELEMENT "departamentos";
  
  
-- PASO 4: Casos de Prueba de Inserción

-- Caso A: Inserción VÁLIDA (cumple todas las reglas de la definición XSD)
INSERT INTO tabla_departamentos_xml VALUES (
  XMLTYPE('<?xml version="1.0"?>
<departamentos>
  <departamento id="10">
    <nombre>Administration</nombre>
    <empleados>
      <empleado id="200">
        <nombre>Felipe</nombre>
        <apellido>Supelano</apellido>
        <email>FSUPELANO</email>
      </empleado>
    </empleados>
  </departamento>
</departamentos>')
);

-- Caso B: Inserción INVÁLIDA (se omite el atributo obligatorio "id" en departamento)
INSERT INTO tabla_departamentos_xml VALUES (
  XMLTYPE('<?xml version="1.0"?>
<departamentos>
  <departamento>
    <nombre>Ventas</nombre>
  </departamento>
</departamentos>')
);

COMMIT;


-- PASO 5: Verificación de la validación del esquema mediante consulta SQL
-- Utiliza isSchemaValid() para evaluar el cumplimiento del XSD registrado (1=Válido, 0=Inválido)
SELECT 
  t.getClobVal() AS xml_contenido,
  CASE 
    WHEN t.isSchemaValid('http://localhost/departamentos.xsd') = 1 THEN 'VÁLIDO (1)'
    ELSE 'INVÁLIDO (0)'
  END AS estado_validacion
FROM tabla_departamentos_xml t;
