@SuppressWarnings('PMD.AvoidGlobalModifier, PMD.EmptyStatementBlock, PMD.EmptyIfStmt, PMD.ExcessiveClassLength, PMD.NcssMethodCount, PMD.ExcessiveParameterList, PMD.CognitiveComplexity')
/**
 * Mustache.cls - Logic-less {{mustache}} templates in Apex
 *
 * Apex implementation of mustache.js templating system.
 *
 * reference see : mustache(5) docs : https://mustache.github.io/mustache.5.html
 *
 * See MustacheTest for examples of the supported fetures.
 *
 * This Mustache implementation now supports the following key features:
 *
 *    Variable substitution with HTML escaping
 *    Unescaped variable rendering
 *    Section rendering for conditional content
 *    Section iteration over lists
 *    Inverted sections for negative conditions
 *    Nested property access via dotted notation
 *
 * Future Features of Apex Mustache:
 *  Lambdas
 *  Partial
 *  Parents
 *  Blocks
 */
global with sharing class Mustache {
    public static final String NAME = 'mustache.apex';
    public static final String VERSION = '1.0.0';
    public static final List<String> DEFAULT_TAGS = new List<String>{'{{', '}}'};

    private static final Writer DEFAULT_WRITER = new Writer();

    /**
     * Clears the template cache.
     */
    global static void clearCache() {
        DEFAULT_WRITER.clearCache();
    }

    /**
     * Parses the given template with the given tags and returns the array of tokens.
     */
    global static List<Object> parse(String template, List<String> tags) {
        return DEFAULT_WRITER.parse(template, tags);
    }

    /**
     * Renders the given template with the given view and partials.
     */
    global static String render(String template, Object view, Map<String, String> partials, Object config) {
        if (template == null) {
            throw new MustacheException('Invalid template! Template should be a "string"');
        }

        if (view == null) {
            throw new MustacheException('Invalid view! View cannot be null');
        }

        return DEFAULT_WRITER.render(template, view, partials, config);
    }

    /**
     * Renders the given template with the given view and partials.
     */
    global static String render(String template, Object view, Map<String, String> partials) {
        return render(template, view, partials, null);
    }

    /**
     * Renders the given template with the given view.
     */
    global static String render(String template, Object view) {
        return render(template, view, null, null);
    }

    /**
     * HTML escaping for special characters
     */
    public static String escapeHtml(String text) {
        if (text == null) {
            return '';
        }

        return text
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;')
            .replace('\'', '&#39;')
            .replace('/', '&#x2F;')
            .replace('`', '&#x60;')
            .replace('=', '&#x3D;')
            ;
    }

    /**
     * Scanner class for scanning through template strings
     */
    public class Scanner {
        private String content;
        private String tail;
        private Integer pos;

        public Scanner(String textContent) {
            this.content = textContent;
            this.tail = textContent;
            this.pos = 0;
        }

        /**
         * Returns whether the scan is at end of string.
         */
        public Boolean eos() {
            return this.tail == '';
        }

        /**
         * Scans for a match at the beginning of the string.
         */
        public String scan(String regexPattern) {
            try {
                Pattern p = Pattern.compile(regexPattern);
                Matcher m = p.matcher(this.tail);

                if (m.lookingAt()) {
                    String match = m.group(0);
                    this.tail = this.tail.substring(match.length());
                    this.pos += match.length();
                    return match;
                }
            } catch (Exception e) {
                // If the pattern isn't a valid regex, check for literal match at beginning
                if (this.tail.startsWith(regexPattern)) {
                    String match = regexPattern;
                    this.tail = this.tail.substring(match.length());
                    this.pos += match.length();
                    return match;
                }
            }
            return '';
        }

        /**
         * Scans until a pattern is found.
         * Optimized to prevent CPU limit issues.
         */
        public String scanUntil(String regexPattern) {
            // Safety check - if tail is empty, return empty string
            if (String.isEmpty(this.tail)) {
                return '';
            }

            // Safety check - if the pattern is empty or null, return the entire tail
            if (String.isEmpty(regexPattern)) {
                String match = this.tail;
                this.pos += this.tail.length();
                this.tail = '';
                return match;
            }

            // For large strings, try to limit the processing
            if (this.tail.length() > 1000) {
                // First try to find the pattern in the first 1000 characters
                String truncatedTail = this.tail.substring(0, 1000);

                try {
                    Pattern p = Pattern.compile(regexPattern);
                    Matcher m = p.matcher(truncatedTail);

                    if (m.find()) {
                        Integer index = m.start();
                        String match;

                        if (index == 0) {
                            match = '';
                        } else {
                            match = this.tail.substring(0, index);
                            this.tail = this.tail.substring(index);
                        }

                        this.pos += match.length();
                        return match;
                    }
                } catch (Exception e) {
                    // If regex fails, try as literal string in the truncated portion
                    Integer index = truncatedTail.indexOf(regexPattern);
                    if (index != -1) {
                        String match;
                        if (index == 0) {
                            match = '';
                        } else {
                            match = this.tail.substring(0, index);
                            this.tail = this.tail.substring(index);
                        }
                        this.pos += match.length();
                        return match;
                    }
                }

                // If pattern not found in first 1000 chars, process chunked to prevent CPU limit
                // Return first 500 chars and advance pointer
                String match = this.tail.substring(0, 500);
                this.tail = this.tail.substring(500);
                this.pos += 500;
                return match;
            }

            // For smaller strings, use the original implementation
            try {
                Pattern p = Pattern.compile(regexPattern);
                Matcher m = p.matcher(this.tail);

                if (m.find()) {
                    Integer index = m.start();
                    String match;

                    if (index == 0) {
                        match = '';
                    } else {
                        match = this.tail.substring(0, index);
                        this.tail = this.tail.substring(index);
                    }

                    this.pos += match.length();
                    return match;
                }
            } catch (Exception e) {
                // If the pattern isn't a valid regex, try to find it as a literal string
                Integer index = this.tail.indexOf(regexPattern);
                if (index != -1) {
                    String match;
                    if (index == 0) {
                        match = '';
                    } else {
                        match = this.tail.substring(0, index);
                        this.tail = this.tail.substring(index);
                    }
                    this.pos += match.length();
                    return match;
                }
            }

            // No match found, return the entire tail
            String match = this.tail;
            this.pos += this.tail.length();
            this.tail = '';
            return match;
        }
    }

    /**
     * Context class for storing view hierarchy
     */
    public class Context {
        private Object view;
        private Map<String, Object> cache;
        private Context parent;

        public Context(Object view, Context parentContext) {
            this.view = view;
            this.cache = new Map<String, Object>{ '.' => this.view };
            this.parent = parentContext;
        }

        /**
         * Creates a new context with the given view and this as parent.
         */
        public Context push(Object view) {
            return new Context(view, this);
        }

        /**
         * Looks up a value from the view hierarchy.
         */
        public Object lookup(String name) {
            if (cache.containsKey(name)) {
                return cache.get(name);
            }

            Object value = null;

            // Break the name into parts (e.g., 'a.b.c' -> ['a', 'b', 'c'])
            List<String> names = name.split('\\.');

            // Start with the current view
            value = this.view;

            // Walk through names to get the nested property
            for (Integer i = 0; i < names.size() && value != null; i++) {
                String part = names[i];

                // Handle different value types
                if (value instanceof Map<String, Object>) {
                    value = ((Map<String, Object>)value).get(part);
                }
                else if (value instanceof Map<String, String>) {
                    value = ((Map<String, String>)value).get(part);
                }
                else if (value instanceof SObject) {
                    SObject sobj = (SObject)value;
                    try {
                        value = sobj.get(part);
                    } catch (Exception e) {
                        value = null;
                    }
                }
                else if (value instanceof List<Object>) {
                    try {
                        Integer index = Integer.valueOf(part);
                        List<Object> listValue = (List<Object>)value;
                        if (index >= 0 && index < listValue.size()) {
                            value = listValue[index];
                        } else {
                            value = null;
                        }
                    } catch (Exception e) {
                        value = null;
                    }
                }
                else {
                    // Try to access property via reflection (not practical in Apex)
                    value = null;
                }
            }

            // Cache the resolved value
            cache.put(name, value);

            // If we couldn't find the property in this context, try the parent
            if (value == null && this.parent != null) {
                value = this.parent.lookup(name);
            }

            return value;
        }
    }

    /**
     * Writer class for parsing and rendering templates
     */
    public class Writer {
        private TemplateCache templateCache;

        public Writer() {
            this.templateCache = new TemplateCache();
        }

        /**
         * Clears the template cache.
         */
        public void clearCache() {
            if (this.templateCache != null) {
                this.templateCache.clear();
            }
        }

        /**
         * Parses the template with the given tags and returns the array of tokens.
         */
        public List<Object> parse(String template, List<String> tags) {
            if (template == null) {
                return new List<Object>();
            }

            String cacheKey = template + ':' + (tags != null ? String.join(tags, ':') :
                                         String.join(DEFAULT_TAGS, ':'));

            List<Object> tokens = this.templateCache.get(cacheKey);

            if (tokens == null) {
                tokens = parseTemplate(template, tags);
                this.templateCache.set(cacheKey, tokens);
            }

            return tokens;
        }

        /**
         * Parses the template with the given tags and returns the array of tokens.
         */
        private List<Object> parseTemplate(String template, List<String> tagsParam) {
            if (String.isEmpty(template)) {
                return new List<Object>();
            }

            List<String> tags = tagsParam != null ? tagsParam : DEFAULT_TAGS;
            List<Object> tokens = new List<Object>();

            List<Object> sections = new List<Object>(); // Stack to track open sections
            List<Object> nestedTokens = tokens; // The tokens array we're currently adding to

            // Basic tokenization for template parsing
            Scanner scanner = new Scanner(template);
            String openingTag = tags[0];
            String closingTag = tags[1];
            String text;

            // Escape regex special characters in tags
            String escapedOpeningTag = openingTag.replace('{', '\\{').replace('[', '\\[');
            String escapedClosingTag = closingTag.replace('}', '\\}').replace(']', '\\]');

            while (!scanner.eos()) {
                // Scan until we find an opening tag
                text = scanner.scanUntil(escapedOpeningTag);

                // Add the text token if not empty
                if (!String.isEmpty(text)) {
                    nestedTokens.add(new List<Object>{'text', text});
                }

                // Scan the opening tag
                if (scanner.scan(escapedOpeningTag) == '') {
                    break; // No more opening tags found
                }

                // Check for triple mustache syntax {{{value}}}
                boolean isTripleMustache = false;
                if (openingTag == '{{' && !scanner.eos() && scanner.tail.startsWith('{')) {
                    // Consume the extra { for triple mustache
                    scanner.scan('\\{');
                    isTripleMustache = true;
                }

                // Scan the tag name
                String name = scanner.scanUntil(escapedClosingTag);

                // If we can't find a closing tag, break
                if (scanner.scan(escapedClosingTag) == '') {
                    break;
                }

                // For triple mustache, we need to consume the extra } after the closing tag
                if (isTripleMustache && !scanner.eos() && scanner.tail.startsWith('}')) {
                    scanner.scan('\\}');
                }

                // Add the tag token
                if (!String.isEmpty(name)) {
                    // Basic tag type detection
                    if (name.startsWith('#')) {
                        // Section start
                        String sectionName = name.substring(1).trim();
                        List<Object> section = new List<Object>{'#', sectionName, new List<Object>()};
                        nestedTokens.add(section);
                        sections.add(section);
                        nestedTokens = (List<Object>)section[2]; // Add subsequent tokens to this section's token list
                    } else if (name.startsWith('/')) {
                        // Section end
                        String sectionName = name.substring(1).trim();
                        if (sections.isEmpty()) {
                            throw new MustacheException('Unopened section: ' + sectionName);
                        }

                        // Get the last opened section
                        List<Object> section = (List<Object>)sections.remove(sections.size() - 1);
                        String openSection = (String)section[1];

                        if (openSection != sectionName) {
                            throw new MustacheException('Unclosed section: ' + openSection);
                        }

                        // We're no longer in this section, so update nestedTokens
                        if (sections.isEmpty()) {
                            nestedTokens = tokens;
                        } else {
                            List<Object> currentSection = (List<Object>)sections.get(sections.size() - 1);
                            nestedTokens = (List<Object>)currentSection[2];
                        }
                    } else if (name.startsWith('^')) {
                        // Inverted section start
                        String sectionName = name.substring(1).trim();
                        List<Object> section = new List<Object>{'^', sectionName, new List<Object>()};
                        nestedTokens.add(section);
                        sections.add(section);
                        nestedTokens = (List<Object>)section[2]; // Add subsequent tokens to this section's token list
                    } else if (name.startsWith('&')) {
                        // Unescaped variable
                        nestedTokens.add(new List<Object>{'&', name.substring(1).trim()});
                    } else if (isTripleMustache) {
                        // Triple mustache syntax for unescaped variable
                        nestedTokens.add(new List<Object>{'{', name.trim()});
                    } else if (name.startsWith('!')) {
                        // Comment - no token added
                    } else if (name.startsWith('>')) {
                        // Partial
                        nestedTokens.add(new List<Object>{'>', name.substring(1).trim()});
                    } else if (name.startsWith('=')) {
                        // Set delimiters - not implementing yet
                    } else {
                        // Regular variable
                        nestedTokens.add(new List<Object>{'name', name.trim()});
                    }
                }
            }

            // Check for unclosed sections
            if (!sections.isEmpty()) {
                List<Object> section = (List<Object>)sections.get(sections.size() - 1);
                throw new MustacheException('Unclosed section: ' + (String)section[1]);
            }

            return tokens;
        }

        /**
         * Renders the template with the given view and partials.
         */
        public String render(String template, Object view, Map<String, String> partials, Object config) {
            List<String> tags = getConfigTags(config);
            List<Object> tokens = this.parse(template, tags);
            Context context = (view instanceof Context) ? (Context)view : new Context(view, null);
            return this.renderTokens(tokens, context, partials, template, config);
        }

        /**
         * Renders the tokens with the given context and partials.
         */
        private String renderTokens(List<Object> tokens, Context context, Map<String, String> partials,
                                   String originalTemplate, Object config) {
            if (tokens == null || tokens.isEmpty()) {
                return '';
            }

            String result = '';

            for (Object tokenObj : tokens) {
                List<Object> token = (List<Object>)tokenObj;
                String tokenType = (String)token[0];

                if (tokenType == 'text') {
                    result += (String)token[1];
                } else if (tokenType == 'name') {
                    String value = '';
                    Object contextValue = context.lookup((String)token[1]);

                    if (contextValue != null) {
                        value = String.valueOf(contextValue);
                    }

                    result += escapeHtml(value);
                } else if (tokenType == '&' || tokenType == '{') {
                    // Unescaped value (either with & or triple mustache)
                    result += unescapedValue(token, context);
                } else if (tokenType == '#') {
                    // Section - will implement later
                    result += renderSection(token, context, partials, originalTemplate, config);
                } else if (tokenType == '^') {
                    // Inverted section
                    result += renderInverted(token, context, partials, originalTemplate, config);
                } else if (tokenType == '>') {
                    // Partial - will implement later
                    result += renderPartial(token, context, partials, config);
                }
            }

            return result;
        }

        /**
         * Renders the section with the given token, context, and partials.
         */
        private String renderSection(List<Object> token, Context context, Map<String, String> partials,
                                   String originalTemplate, Object config) {
            if (token.size() < 3) {
                return ''; // Invalid token
            }

            String name = (String)token[1];
            List<Object> sectionTokens = (List<Object>)token[2];

            Object value = context.lookup(name);

            if (value == null) {
                return ''; // Don't render
            }

            String result = '';

            // Handle different value types for section
            if (value instanceof Boolean) {
                Boolean boolValue = (Boolean)value;
                if (boolValue) {
                    // Render section with current context
                    result = renderTokens(sectionTokens, context, partials, originalTemplate, config);
                }
            } else if (value instanceof List<Object>) {
                // Render section once for each item in the list
                List<Object> listValue = (List<Object>)value;
                for (Object item : listValue) {
                    // Push item to context stack
                    Context newContext = context.push(item);
                    result += renderTokens(sectionTokens, newContext, partials, originalTemplate, config);
                }
            } else if (value instanceof Map<String, Object>) {
                // Render section with value as context
                Context newContext = context.push(value);
                result = renderTokens(sectionTokens, newContext, partials, originalTemplate, config);
            } else if (value instanceof SObject) {
                // Render section with SObject as context
                Context newContext = context.push(value);
                result = renderTokens(sectionTokens, newContext, partials, originalTemplate, config);
            } else {
                // For any other truthy value, render with current context
                result = renderTokens(sectionTokens, context, partials, originalTemplate, config);
            }

            return result;
        }

        /**
         * Renders the inverted section with the given token, context, and partials.
         * Inverted sections render when the value is falsey (null, false, empty list)
         */
        private String renderInverted(List<Object> token, Context context, Map<String, String> partials,
                                    String originalTemplate, Object config) {
            if (token.size() < 3) {
                return ''; // Invalid token
            }

            String name = (String)token[1];
            List<Object> sectionTokens = (List<Object>)token[2];

            Object value = context.lookup(name);
            String result = '';

            // Render content if the value is falsey
            if (value == null) {
                result = renderTokens(sectionTokens, context, partials, originalTemplate, config);
            } else if (value instanceof Boolean && !(Boolean)value) {
                result = renderTokens(sectionTokens, context, partials, originalTemplate, config);
            } else if (value instanceof List<Object> && ((List<Object>)value).isEmpty()) {
                result = renderTokens(sectionTokens, context, partials, originalTemplate, config);
            } else if (value instanceof String && String.isEmpty((String)value)) {
                result = renderTokens(sectionTokens, context, partials, originalTemplate, config);
            } else if (value instanceof Map<String, Object> && ((Map<String, Object>)value).isEmpty()) {
                result = renderTokens(sectionTokens, context, partials, originalTemplate, config);
            }

            return result;
        }

        /**
         * Indents the given partial.
         */
        private String indentPartial(String partial, String indentation, Boolean lineHasNonSpace) {
            // TODO: Implement indentPartial
            return ''; // Placeholder - will be implemented fully
        }

        /**
         * Renders the partial with the given token, context, and partials.
         */
        private String renderPartial(List<Object> token, Context context, Map<String, String> partials, Object config) {
            if (token.size() < 2) {
                return ''; // Invalid token
            }

            // Get the partial name from the token
            String name = (String)token[1];

            // If partials map is null or doesn't contain the partial, return empty string
            if (partials == null || !partials.containsKey(name)) {
                return '';
            }

            // Get the partial template
            String partial = partials.get(name);

            // Parse and render the partial with the current context
            List<String> tags = getConfigTags(config);
            List<Object> tokens = parse(partial, tags);
            return renderTokens(tokens, context, partials, partial, config);
        }

        /**
         * Returns the unescaped value for the given token.
         */
        private String unescapedValue(List<Object> token, Context context) {
            if (token.size() < 2) {
                return ''; // Invalid token
            }

            String name = (String)token[1];
            Object value = context.lookup(name);

            // Convert value to string if not null
            return value != null ? String.valueOf(value) : '';
        }

        /**
         * Returns the escaped value for the given token.
         */
        private String escapedValue(List<Object> token, Context context, Object config) {
            // TODO: Implement escapedValue
            return ''; // Placeholder - will be implemented fully
        }

        /**
         * Returns the raw value for the given token.
         */
        private String rawValue(List<Object> token) {
            // TODO: Implement rawValue
            return ''; // Placeholder - will be implemented fully
        }

        /**
         * Gets the tags from the given config.
         */
        public List<String> getConfigTags(Object config) {
            if (config instanceof List<String>) {
                return (List<String>)config;
            }
            else if (config instanceof Map<String, Object>) {
                Object tags = ((Map<String, Object>)config).get('tags');
                if (tags instanceof List<String>) {
                    return (List<String>)tags;
                }
            }
            return null;
        }

        /**
         * Gets the escape function from the given config.
         */
        public String getConfigEscape(Object config) {
            if (config instanceof Map<String, Object>) {
                Object escape = ((Map<String, Object>)config).get('escape');
                if (escape instanceof String) {
                    return (String)escape;
                }
            }
            return null;
        }
    }

    /**
     * Template cache class for caching parsed templates
     */
    public class TemplateCache {
        private Map<String, List<Object>> cache;

        public TemplateCache() {
            this.cache = new Map<String, List<Object>>();
        }

        /**
         * Sets the given key to the given value in the cache.
         */
        public void set(String key, List<Object> value) {
            this.cache.put(key, value);
        }

        /**
         * Gets the value for the given key from the cache.
         */
        public List<Object> get(String key) {
            return this.cache.get(key);
        }

        /**
         * Clears the cache.
         */
        public void clear() {
            this.cache.clear();
        }
    }

    /**
     * Custom exception for Mustache errors
     */
    public class MustacheException extends Exception {}
}
