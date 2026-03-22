# Tines Formula Reference

Complete reference for Tines formula syntax, operators, and function catalog.

## Syntax

### Basic References

```
<<action_name.field>>                     — top-level field from a named action
<<action_name.body.nested.key>>           — nested field access via dot notation
<<action_name.body.items[0]>>             — array index access
<<action_name.body.items[0].name>>        — nested access inside array element
```

### Credential and Resource References

```
<<CREDENTIAL.credential_name>>           — resolve a stored credential value
<<RESOURCE.resource_name>>               — resolve a text resource
<<RESOURCE.resource_name.key>>           — resolve a key from a JSON resource
```

### Pipe Chaining

Pipes transform a value left-to-right:

```
<<action_name.body.email | downcase | strip>>
<<action_name.body.tags | join: ", ">>
<<action_name.body.name | truncate: 50>>
```

### Default Values

```
<<action_name.body.optional_field | default: "fallback">>
<<action_name.body.count | default: 0>>
```

### Conditionals

```
IF(<<action_name.body.severity>> = "critical", "page", "log")
IF(<<action_name.body.score>> > 80, "high", IF(<<action_name.body.score>> > 40, "medium", "low"))
```

## Operators

| Operator | Description |
|----------|-------------|
| `=` | Equal |
| `!=` | Not equal |
| `>` | Greater than |
| `>=` | Greater than or equal |
| `<` | Less than |
| `<=` | Less than or equal |
| `AND` / `&&` | Logical AND |
| `OR` / `\|\|` | Logical OR |
| `+` | Addition / string concatenation |
| `-` | Subtraction |
| `*` | Multiplication |
| `/` | Division |

---

## Function Reference

### Text Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `UPCASE` | `UPCASE(str)` | Convert to uppercase |
| `DOWNCASE` | `DOWNCASE(str)` | Convert to lowercase |
| `CAPITALIZE` | `CAPITALIZE(str)` | Capitalize first letter |
| `TRIM` | `TRIM(str)` | Remove leading/trailing whitespace |
| `STRIP` | `STRIP(str)` | Alias for TRIM |
| `SPLIT` | `SPLIT(str, delimiter)` | Split string into array |
| `JOIN` | `JOIN(array, delimiter)` | Join array into string |
| `REPLACE` | `REPLACE(str, old, new)` | Replace first occurrence |
| `REPLACE_ALL` | `REPLACE_ALL(str, old, new)` | Replace all occurrences |
| `REGEX_REPLACE` | `REGEX_REPLACE(str, pattern, replacement)` | Regex-based replacement |
| `REGEX_EXTRACT` | `REGEX_EXTRACT(str, pattern)` | Extract first regex match |
| `REGEX_EXTRACT_ALL` | `REGEX_EXTRACT_ALL(str, pattern)` | Extract all regex matches |
| `SUBSTRING` | `SUBSTRING(str, start, length)` | Extract substring |
| `LEFT` | `LEFT(str, n)` | First n characters |
| `RIGHT` | `RIGHT(str, n)` | Last n characters |
| `LENGTH` | `LENGTH(str)` | Character count |
| `CONTAINS` | `CONTAINS(str, search)` | True if str contains search |
| `STARTS_WITH` | `STARTS_WITH(str, prefix)` | True if str starts with prefix |
| `ENDS_WITH` | `ENDS_WITH(str, suffix)` | True if str ends with suffix |
| `APPEND` | `APPEND(str, suffix)` | Append string |
| `PREPEND` | `PREPEND(str, prefix)` | Prepend string |
| `TRUNCATE` | `TRUNCATE(str, max_length)` | Truncate with ellipsis |
| `REVERSE` | `REVERSE(str)` | Reverse string |
| `URL_ENCODE` | `URL_ENCODE(str)` | Percent-encode for URLs |
| `URL_DECODE` | `URL_DECODE(str)` | Decode percent-encoded string |

### Array and Object Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `FLATTEN` | `FLATTEN(array)` | Flatten nested arrays one level |
| `MERGE` | `MERGE(obj1, obj2)` | Merge two objects (right wins) |
| `COMPACT` | `COMPACT(array)` | Remove null/blank entries |
| `FILTER` | `FILTER(array, key, value)` | Keep elements where key == value |
| `MAP` | `MAP(array, expression)` | Transform each element |
| `GROUP_BY` | `GROUP_BY(array, key)` | Group elements by key value |
| `SORT` | `SORT(array, key)` | Sort by key (ascending) |
| `UNIQ` | `UNIQ(array)` | Remove duplicates |
| `SIZE` | `SIZE(array_or_obj)` | Element count |
| `FIRST` | `FIRST(array)` | First element |
| `LAST` | `LAST(array)` | Last element |
| `NTH` | `NTH(array, index)` | Element at index |
| `PUSH` | `PUSH(array, value)` | Append value to array |
| `POP` | `POP(array)` | Remove and return last element |
| `REVERSE` | `REVERSE(array)` | Reverse array order |
| `WHERE` | `WHERE(array, key, op, value)` | Filter with operator |
| `PLUCK` | `PLUCK(array, key)` | Extract one key from each element |
| `KEYS` | `KEYS(object)` | Array of object keys |
| `VALUES` | `VALUES(object)` | Array of object values |
| `INCLUDES` | `INCLUDES(array, value)` | True if array contains value |
| `EXCEPT` | `EXCEPT(object, key1, key2...)` | Object without listed keys |
| `ONLY` | `ONLY(object, key1, key2...)` | Object with only listed keys |
| `ZIP` | `ZIP(keys_array, values_array)` | Combine into key-value object |

### Date and Time Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `DATE` | `DATE(str, format)` | Parse date string |
| `NOW` | `NOW()` | Current UTC timestamp |
| `DATE_DIFF` | `DATE_DIFF(date1, date2, unit)` | Difference in unit (seconds, minutes, hours, days) |
| `YEAR` | `YEAR(date)` | Extract year |
| `MONTH` | `MONTH(date)` | Extract month (1-12) |
| `DAY` | `DAY(date)` | Extract day of month |
| `HOUR` | `HOUR(date)` | Extract hour (0-23) |
| `MINUTE` | `MINUTE(date)` | Extract minute (0-59) |
| `SECOND` | `SECOND(date)` | Extract second (0-59) |
| `DISTANCE_OF_TIME_IN_WORDS` | `DISTANCE_OF_TIME_IN_WORDS(date1, date2)` | Human-readable time difference |
| `STRFTIME` | `STRFTIME(date, format)` | Format date with strftime pattern |

### Math Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `ABS` | `ABS(n)` | Absolute value |
| `CEIL` | `CEIL(n)` | Round up to nearest integer |
| `FLOOR` | `FLOOR(n)` | Round down to nearest integer |
| `ROUND` | `ROUND(n, decimals)` | Round to n decimal places |
| `SQRT` | `SQRT(n)` | Square root |
| `POWER` | `POWER(base, exp)` | Exponentiation |
| `SUM` | `SUM(array)` | Sum of numeric array |
| `AVERAGE` | `AVERAGE(array)` | Mean of numeric array |
| `MIN` | `MIN(array_or_a, b)` | Minimum value |
| `MAX` | `MAX(array_or_a, b)` | Maximum value |
| `MODULO` | `MODULO(a, b)` | Remainder of a / b |
| `RANDOM` | `RANDOM(min, max)` | Random integer in range |

### Logical Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `IF` | `IF(condition, true_val, false_val)` | Conditional expression |
| `IF_ERROR` | `IF_ERROR(expression, fallback)` | Return fallback if expression errors |
| `SWITCH` | `SWITCH(value, case1, result1, ..., default)` | Multi-way branch |
| `AND` | `AND(a, b, ...)` | True if all arguments are truthy |
| `OR` | `OR(a, b, ...)` | True if any argument is truthy |
| `NOT` | `NOT(value)` | Boolean negation |
| `AT_LEAST` | `AT_LEAST(n, cond1, cond2, ...)` | True if >= n conditions are true |
| `AT_MOST` | `AT_MOST(n, cond1, cond2, ...)` | True if <= n conditions are true |
| `TERNARY` | `TERNARY(condition, true_val, false_val)` | Alias for IF |

### Parsing Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `JSON_PARSE` | `JSON_PARSE(str)` | Parse JSON string to object |
| `XML_PARSE` | `XML_PARSE(str)` | Parse XML string to object |
| `CSV_PARSE` | `CSV_PARSE(str)` | Parse CSV string to array of arrays |
| `YAML_PARSE` | `YAML_PARSE(str)` | Parse YAML string to object |
| `EML_PARSE` | `EML_PARSE(str)` | Parse email (.eml) to structured object |
| `BASE64_DECODE` | `BASE64_DECODE(str)` | Decode base64 string |
| `HTML_STRIP` | `HTML_STRIP(str)` | Remove HTML tags |
| `REGEX_EXTRACT` | `REGEX_EXTRACT(str, pattern)` | Extract first match from string |

### Crypto Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `MD5` | `MD5(str)` | MD5 hex digest |
| `SHA256` | `SHA256(str)` | SHA-256 hex digest |
| `SHA1` | `SHA1(str)` | SHA-1 hex digest |
| `HMAC_SHA256` | `HMAC_SHA256(str, key)` | HMAC-SHA256 signature |
| `HMAC_SHA1` | `HMAC_SHA1(str, key)` | HMAC-SHA1 signature |
| `AES_ENCRYPT` | `AES_ENCRYPT(str, key)` | AES-256 encryption |
| `AES_DECRYPT` | `AES_DECRYPT(str, key)` | AES-256 decryption |
| `RSA_ENCRYPT` | `RSA_ENCRYPT(str, public_key)` | RSA encryption |
| `JWT_SIGN` | `JWT_SIGN(payload, key, algorithm)` | Sign a JWT |
| `JWT_DECODE` | `JWT_DECODE(token)` | Decode JWT payload (no verification) |
| `BASE64_ENCODE` | `BASE64_ENCODE(str)` | Encode string to base64 |
| `BASE64_DECODE` | `BASE64_DECODE(str)` | Decode base64 to string |

### Validation Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `IS_EMAIL` | `IS_EMAIL(str)` | True if valid email format |
| `IS_URL` | `IS_URL(str)` | True if valid URL format |
| `IS_IPV4` | `IS_IPV4(str)` | True if valid IPv4 address |
| `IS_IPV6` | `IS_IPV6(str)` | True if valid IPv6 address |
| `IS_JSON` | `IS_JSON(str)` | True if valid JSON |
| `IS_BLANK` | `IS_BLANK(value)` | True if nil, empty string, or whitespace |
| `IS_PRESENT` | `IS_PRESENT(value)` | True if not blank |
| `IS_NUMBER` | `IS_NUMBER(value)` | True if numeric |
| `IS_ARRAY` | `IS_ARRAY(value)` | True if array |
| `IS_OBJECT` | `IS_OBJECT(value)` | True if object/hash |
| `TYPE` | `TYPE(value)` | Returns type as string (`"string"`, `"number"`, `"array"`, `"object"`, `"boolean"`, `"null"`) |
