/**
 * Test class for the Mustache template engine functionality
 */
@IsTest
private class MustacheTest {

    @IsTest
    static void testScannerBasicFunctionality() {
        // A simple template string to test with
        String template = 'Hello {{name}}, welcome to {{location}}!';

        // Create a scanner instance
        Mustache.Scanner scanner = new Mustache.Scanner(template);

        // Test scanning until the opening tag
        String textBeforeTag = scanner.scanUntil('\\{\\{');
        System.assertEquals('Hello ', textBeforeTag, 'Should scan until the first opening tag');

        // Test scanning the opening tag
        String openingTag = scanner.scan('\\{\\{');
        System.assertEquals('{{', openingTag, 'Should scan the opening tag');

        // Test scanning the tag name
        String tagName = scanner.scanUntil('\\}\\}');
        System.assertEquals('name', tagName, 'Should scan the tag name');

        // Test scanning the closing tag
        String closingTag = scanner.scan('\\}\\}');
        System.assertEquals('}}', closingTag, 'Should scan the closing tag');

        // Test scanning until the next opening tag
        String textBetweenTags = scanner.scanUntil('\\{\\{');
        System.assertEquals(', welcome to ', textBetweenTags, 'Should scan until the next opening tag');

        // Test eos (end of string) returns false since we're not at the end yet
        System.assertEquals(false, scanner.eos(), 'Should not be at end of string yet');
    }

    @IsTest
    static void testScannerWithLiteralStrings() {
        // A simple string to test with
        String text = 'This is a test string with some words. Words are important.';

        // Create a scanner instance
        Mustache.Scanner scanner = new Mustache.Scanner(text);

        // Test scanning until a literal string
        String firstPart = scanner.scanUntil('test');
        System.assertEquals('This is a ', firstPart, 'Should scan until the word "test"');

        // Test scanning a literal string
        String scannedWord = scanner.scan('test');
        System.assertEquals('test', scannedWord, 'Should scan the word "test"');

        // Test scanning until a period
        String restOfSentence = scanner.scanUntil('\\.');
        System.assertEquals(' string with some words', restOfSentence, 'Should scan until the period');

        // Test scanning the period
        String period = scanner.scan('\\.');
        System.assertEquals('.', period, 'Should scan the period');

        // Test scanning all the remaining text
        String remainingText = scanner.scanUntil('xyz'); // Something not in the string
        System.assertEquals(' Words are important.', remainingText, 'Should scan all remaining text');

        // Test eos (end of string) returns true since we're at the end
        System.assertEquals(true, scanner.eos(), 'Should be at end of string');
    }

    @IsTest
    static void testScannerWithSectionTags() {
        // A template with section tags
        String template = 'Hello {{name}}! {{#items}}Item{{/items}}';

        // Create a scanner instance
        Mustache.Scanner scanner = new Mustache.Scanner(template);

        // Scan until first tag
        String intro = scanner.scanUntil('\\{\\{');
        System.assertEquals('Hello ', intro, 'Should scan introduction text');

        // Scan the opening tag
        scanner.scan('\\{\\{');

        // Scan the tag name
        String nameTag = scanner.scanUntil('\\}\\}');
        System.assertEquals('name', nameTag, 'Should scan the name tag');

        // Scan closing tag
        scanner.scan('\\}\\}');

        // Scan until section start
        String exclamation = scanner.scanUntil('\\{\\{');
        System.assertEquals('! ', exclamation, 'Should scan exclamation and space');

        // Scan opening tag of section
        scanner.scan('\\{\\{');

        // Scan section symbol and name
        String sectionTag = scanner.scanUntil('\\}\\}');
        System.assertEquals('#items', sectionTag, 'Should scan the section tag with symbol');

        // Scan closing tag
        scanner.scan('\\}\\}');

        // Scan until end section tag
        String itemText = scanner.scanUntil('\\{\\{');
        System.assertEquals('Item', itemText, 'Should scan the item text');

        // scan with an invalid regex
        Mustache.Scanner scanner2 = new Mustache.Scanner('\\\\\\\\');
        String invalidRegex = scanner2.scan('\\\\\\');
        System.assertEquals(3, invalidRegex.length(), 'Should return 3 characters ');

        Mustache.Scanner scanner3 = new Mustache.Scanner('Hello\\\\\\\\');
        String invalidRegex2 = scanner3.scan('\\\\\\');
        System.assertEquals('', invalidRegex2, 'Should return empty string');
    }

    @IsTest
    static void testScannerAdditionalPatterns() {
        // Test with a shorter template and specific scan operations
        String template = 'Name: {{name}}, Age: {{age}}';
        Mustache.Scanner scanner = new Mustache.Scanner(template);

        // Scan until first tag
        scanner.scanUntil('\\{\\{'); // "Name: "
        scanner.scan('\\{\\{'); // "{{"
        scanner.scanUntil('\\}\\}'); // "name"
        scanner.scan('\\}\\}'); // "}}"

        // Test scanning comma and space
        String comma = scanner.scanUntil('Age');
        System.assertEquals(', ', comma, 'Should scan comma and space');

        // Test scanning a specific word
        String age = scanner.scan('Age');
        System.assertEquals('Age', age, 'Should scan the word "Age"');

        // Finish scanning
        String remaining = scanner.scanUntil('$'); // Nothing matching $ so should get everything
        System.assertEquals(': {{age}}', remaining, 'Should scan the rest of the template');

        // Verify we're at the end
        System.assertEquals(true, scanner.eos(), 'Should be at end of string');
    }

    @IsTest
    static void testSimpleVariableRendering() {
        // Simple template with variable substitution
        String template = 'Hello {{name}}!';

        // Create a view object as a Map
        Map<String, Object> view = new Map<String, Object>{
            'name' => 'World'
        };

        // Render the template
        String result = Mustache.render(template, view);

        // Verify the result
        System.assertEquals('Hello World!', result, 'Should substitute the variable correctly');
    }

    @IsTest
    static void testUnescapedVariableRendering() {
        // Template with variable that needs HTML escaping
        String template = 'Welcome {{&name}}';

        // Create a view with HTML special characters
        Map<String, Object> view = new Map<String, Object>{
            'name' => '<b>John & Jane</b>'
        };

        // Render the template
        String result = Mustache.render(template, view);

        // Verify HTML characters are escaped
        System.assertEquals('Welcome <b>John & Jane</b>', result, 'Should not escape HTML special characters');
    }

    /**
     * In our Mustache implementation, we're escaping the forward slash to its HTML entity &#x2F;,
     * which is a security best practice to prevent certain types of XSS attacks.
     * This is why in the output </b> becomes &lt;&#x2F;b&gt; rather than just &lt;/b&gt;.
     */
    @IsTest
    static void testEscapedVariableRendering() {
        // Template with variable that needs HTML escaping
        String template = 'Welcome {{name}}';

        // Create a view with HTML special characters
        Map<String, Object> view = new Map<String, Object>{
            'name' => '<b>John & Jane</b>'
        };

        // Render the template
        String result = Mustache.render(template, view);

        // Verify HTML characters are escaped
        System.assertEquals('Welcome &lt;b&gt;John &amp; Jane&lt;&#x2F;b&gt;', result, 'Should escape HTML special characters');
    }

    @IsTest
    static void testSectionRendering() {
        // Template with a section
        String template = 'Welcome{{#showWelcome}} {{name}}{{/showWelcome}}!';

        // Test with section true
        Map<String, Object> view = new Map<String, Object>{
            'showWelcome' => true,
            'name' => 'John'
        };

        String result = Mustache.render(template, view);
        System.assertEquals('Welcome John!', result, 'Section should render when value is true');

        // Test with section false
        view = new Map<String, Object>{
            'showWelcome' => false,
            'name' => 'John'
        };

        result = Mustache.render(template, view);
        System.assertEquals('Welcome!', result, 'Section should not render when value is false');
    }

    @IsTest
    static void testSectionWithList() {
        // Template with a section containing a list
        String template = 'Items:{{#items}} {{name}}{{/items}}';

        // Create a list for the section
        List<Object> items = new List<Object>{
            new Map<String, Object>{'name' => 'Item 1'},
            new Map<String, Object>{'name' => 'Item 2'},
            new Map<String, Object>{'name' => 'Item 3'}
        };

        Map<String, Object> view = new Map<String, Object>{
            'items' => items
        };

        String result = Mustache.render(template, view);

        // Each item should be rendered
        System.assertEquals('Items: Item 1 Item 2 Item 3', result, 'Each item in the list should be rendered');
    }

    @IsTest
    static void testInvertedSectionRendering() {
        // Test template with inverted section
        String template = '{{^hasItems}}No items found.{{/hasItems}}{{#hasItems}}Items found!{{/hasItems}}';

        // Test case 1: hasItems is false (inverted section should render)
        Map<String, Object> view1 = new Map<String, Object>{
            'hasItems' => false
        };

        String result1 = Mustache.render(template, view1);
        System.assertEquals('No items found.', result1, 'Should render inverted section when value is false');

        // Test case 2: hasItems is true (inverted section should not render)
        Map<String, Object> view2 = new Map<String, Object>{
            'hasItems' => true
        };

        String result2 = Mustache.render(template, view2);
        System.assertEquals('Items found!', result2, 'Should not render inverted section when value is true');

        // Test case 3: hasItems is null (inverted section should render)
        Map<String, Object> view3 = new Map<String, Object>();

        String result3 = Mustache.render(template, view3, null);
        System.assertEquals('No items found.', result3, 'Should render inverted section when value is missing');
    }

    @IsTest
    static void testInvertedSectionWithEmptyList() {
        // Test template with inverted section for empty list
        String template = '{{^items}}No items available.{{/items}}{{#items}}{{.}}, {{/items}}';

        // Test with empty list (inverted section should render)
        Map<String, Object> view1 = new Map<String, Object>{
            'items' => new List<Object>()
        };

        String result1 = Mustache.render(template, view1);
        System.assertEquals('No items available.', result1, 'Should render inverted section for empty list');

        // Test with non-empty list (inverted section should not render)
        Map<String, Object> view2 = new Map<String, Object>{
            'items' => new List<Object>{'Apple', 'Banana'}
        };

        String result2 = Mustache.render(template, view2);
        System.assertEquals('Apple, Banana, ', result2, 'Should not render inverted section for non-empty list');
    }

    @IsTest
    static void testDottedNameResolution() {
        // Test template with dotted names to access nested properties
        String template = 'User: {{user.name}}, Address: {{user.address.city}}, {{user.address.state}}';

        // Create a nested object structure with maps
        Map<String, Object> address = new Map<String, Object>{
            'street' => '123 Main St',
            'city' => 'San Francisco',
            'state' => 'CA',
            'zip' => '94105'
        };

        Map<String, Object> user = new Map<String, Object>{
            'name' => 'John Doe',
            'age' => 35,
            'address' => address
        };

        Map<String, Object> view = new Map<String, Object>{
            'user' => user
        };

        // Render the template
        String result = Mustache.render(template, view);

        // Verify dotted name resolution works correctly
        System.assertEquals('User: John Doe, Address: San Francisco, CA', result,
                           'Should correctly resolve dotted names for nested properties');
    }

    @IsTest
    static void testMustacheStaticMethods() {
        // Test clearCache method - line 36
        Test.startTest();
        Mustache.clearCache();
        // No assertion needed, just verifying it doesn't throw an exception

        // Test parse method - line 43
        String template = 'Hello {{name}}';
        List<String> tags = new List<String>{'{{', '}}'};
        List<Object> tokens = Mustache.parse(template, tags);
        System.assertNotEquals(null, tokens, 'Parse should return a non-null list of tokens');
        System.assert(!tokens.isEmpty(), 'Parse should return a non-empty list of tokens');

        // Test render with null template - line 52
        Boolean exceptionThrown = false;
        try {
            Mustache.render(null, new Map<String, Object>());
        } catch(Mustache.MustacheException e) {
            exceptionThrown = true;
            System.assertEquals('Invalid template! Template should be a "string"', e.getMessage(),
                          'Exception message should match expected value');
        }
        System.assert(exceptionThrown, 'An exception should be thrown when template is null');

        // Test render with partials - lines 61-62
        String templateWithPartial = 'Hello {{name}}!{{>partial}}';
        Map<String, Object> view = new Map<String, Object>{
            'name' => 'World'
        };
        Map<String, String> partials = new Map<String, String>{
            'partial' => ' This is a partial template.'
        };
        String result = Mustache.render(templateWithPartial, view, partials);
        System.assertEquals('Hello World! This is a partial template.', result,
                      'Should correctly render template with partials');

        // Test render with just template and view - line 68
        String simpleTemplate = 'Welcome, {{name}}!';
        Map<String, Object> simpleView = new Map<String, Object>{
            'name' => 'User'
        };
        String simpleResult = Mustache.render(simpleTemplate, simpleView);
        System.assertEquals('Welcome, User!', simpleResult,
                      'Should correctly render template with just view object');
        Test.stopTest();
        exceptionThrown = false;
        try {
            Mustache.render('Hello {{name}}', null);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'Render should throw an exception when view is null');
    }

    @IsTest
    static void testTemplateCache() {
        // This test verifies the TemplateCache class functionality
        Test.startTest();

        // Create a TemplateCache instance
        Mustache.TemplateCache cache = new Mustache.TemplateCache();

        // Test initial state - cache should be empty
        System.assertEquals(null, cache.get('nonexistent'), 'Cache should return null for nonexistent keys');

        // Test set and get methods
        List<Object> tokens = new List<Object>{
            new List<Object>{'text', 'Hello'},
            new List<Object>{'name', 'name'}
        };

        // Set a value in the cache
        cache.set('template1', tokens);

        // Verify the value was stored correctly
        List<Object> retrievedTokens = cache.get('template1');
        System.assertNotEquals(null, retrievedTokens, 'Retrieved tokens should not be null');
        System.assertEquals(tokens.size(), retrievedTokens.size(), 'Retrieved tokens should have the same size');

        // Test with multiple entries
        List<Object> tokens2 = new List<Object>{
            new List<Object>{'text', 'Goodbye'}
        };
        cache.set('template2', tokens2);

        // Verify both entries exist
        System.assertNotEquals(null, cache.get('template1'), 'First template should still exist');
        System.assertNotEquals(null, cache.get('template2'), 'Second template should exist');

        // Test clear method
        cache.clear();

        // Verify cache is empty after clearing
        System.assertEquals(null, cache.get('template1'), 'Cache should be empty after clear');
        System.assertEquals(null, cache.get('template2'), 'Cache should be empty after clear');

        // Test overwriting existing entry
        cache.set('template3', tokens);
        cache.set('template3', tokens2);
        List<Object> retrievedOverwritten = cache.get('template3');
        System.assertEquals(tokens2.size(), retrievedOverwritten.size(), 'Cache should contain the overwritten value');

        Test.stopTest();
    }

    @IsTest
    static void testConfigMethods() {
        // This test verifies the getConfigTags and getConfigEscape methods
        Test.startTest();

        // Create a Writer instance to access the private methods
        Mustache.Writer writer = new Mustache.Writer();

        // Test getConfigTags with List<String>
        List<String> tags = new List<String>{'[[', ']]'};
        List<String> resultTags = writer.getConfigTags(tags);
        System.assertEquals(tags, resultTags, 'getConfigTags should return the tags list when passed directly');

        // Test getConfigTags with Map<String, Object>
        Map<String, Object> configMap = new Map<String, Object>{
            'tags' => tags
        };
        resultTags = writer.getConfigTags(configMap);
        System.assertEquals(tags, resultTags, 'getConfigTags should extract tags from config map');

        // Test getConfigTags with null
        resultTags = writer.getConfigTags(null);
        System.assertEquals(null, resultTags, 'getConfigTags should return null for null input');

        // Test getConfigTags with invalid map (no tags key)
        Map<String, Object> invalidMap = new Map<String, Object>{
            'notTags' => 'value'
        };
        resultTags = writer.getConfigTags(invalidMap);
        System.assertEquals(null, resultTags, 'getConfigTags should return null for map without tags');

        // Test getConfigEscape with Map<String, Object>
        Map<String, Object> escapeConfig = new Map<String, Object>{
            'escape' => 'customEscape'
        };
        String escapeResult = writer.getConfigEscape(escapeConfig);
        System.assertEquals('customEscape', escapeResult, 'getConfigEscape should extract escape function name');

        // Test getConfigEscape with null
        escapeResult = writer.getConfigEscape(null);
        System.assertEquals(null, escapeResult, 'getConfigEscape should return null for null input');

        // Test getConfigEscape with invalid map (no escape key)
        Map<String, Object> invalidEscapeMap = new Map<String, Object>{
            'notEscape' => 'value'
        };
        escapeResult = writer.getConfigEscape(invalidEscapeMap);
        System.assertEquals(null, escapeResult, 'getConfigEscape should return null for map without escape');

        // Test getConfigEscape with non-string value
        Map<String, Object> nonStringEscapeMap = new Map<String, Object>{
            'escape' => 123
        };
        escapeResult = writer.getConfigEscape(nonStringEscapeMap);
        System.assertEquals(null, escapeResult, 'getConfigEscape should return null for non-string escape value');

        Test.stopTest();
    }

    @IsTest
    static void testRenderPartial() {
        // This test verifies the renderPartial function
        // Test basic partial rendering
        String template = 'Start {{>header}} Middle {{>content}} End';
        Map<String, Object> view = new Map<String, Object>{
            'title' => 'My Page',
            'body' => 'This is the body content.'
        };
        Map<String, String> partials = new Map<String, String>{
            'header' => '<h1>{{title}}</h1>',
            'content' => '<div>{{body}}</div>'
        };

        String result = Mustache.render(template, view, partials);
        String expected = 'Start <h1>My Page</h1> Middle <div>This is the body content.</div> End';

        System.assertEquals(expected, result, 'Partials should be rendered with the current context');

        // Test with nested partials
        template = '{{>outer}}';
        partials = new Map<String, String>{
            'outer' => 'Outer {{>inner}}',
            'inner' => 'Inner {{title}}'
        };

        result = Mustache.render(template, view, partials);
        expected = 'Outer Inner My Page';

        System.assertEquals(expected, result, 'Nested partials should be rendered correctly');

        // Test with missing partial
        template = 'Before {{>missing}} After';

        result = Mustache.render(template, view, partials);
        expected = 'Before  After'; // Missing partial should render as empty string

        System.assertEquals(expected, result, 'Missing partials should render as empty string');
    }

    @IsTest
    static void testUnescapedValue() {
        // This test verifies the unescapedValue function (line 647)
        // Test with triple mustache syntax {{{value}}}
        String template = 'Unescaped: {{{html}}}';
        Map<String, Object> view = new Map<String, Object>{
            'html' => '<b>Bold</b> & <i>Italic</i>'
        };

        String result = Mustache.render(template, view);
        String expected = 'Unescaped: <b>Bold</b> & <i>Italic</i>';

        System.assertEquals(expected, result, 'Triple mustache should not escape HTML');

        // Test with ampersand syntax {{&value}}
        template = 'Unescaped: {{&html}}';

        result = Mustache.render(template, view);
        expected = 'Unescaped: <b>Bold</b> & <i>Italic</i>';

        System.assertEquals(expected, result, 'Ampersand syntax should not escape HTML');

        // Compare with regular escaped syntax
        template = 'Escaped: {{html}} vs Unescaped: {{{html}}}';

        result = Mustache.render(template, view);
        // Get the actual result and verify it matches the expected pattern
        System.debug('Actual result: ' + result);
        // Verify the escaped part contains escaped HTML
        System.assert(result.startsWith('Escaped: &lt;b&gt;Bold&lt;'), 'Escaped part should have escaped HTML');
        System.assert(result.contains('&amp;'), 'Escaped part should have escaped ampersand');
        // Verify the unescaped part contains raw HTML
        System.assert(result.contains('vs Unescaped: <b>Bold</b> & <i>Italic</i>'), 'Unescaped part should have raw HTML');
    }

    @IsTest
    static void testEscapedValue() {
        // This test verifies the escapedValue function (line 655)
        // Test with various HTML special characters
        String template = 'Escaped: {{specialChars}}';
        Map<String, Object> view = new Map<String, Object>{
            'specialChars' => '<script>alert("XSS");</script> & "quoted" text'
        };

        String result = Mustache.render(template, view);
        String expected = 'Escaped: &lt;script&gt;alert(&quot;XSS&quot;);&lt;&#x2F;script&gt; &amp; &quot;quoted&quot; text';

        System.assertEquals(expected, result, 'HTML special characters should be properly escaped');

        // Test with all HTML special characters that should be escaped
        template = 'All special chars: {{allSpecial}}';
        view = new Map<String, Object>{
            'allSpecial' => '< > & " \'' // All characters that should be escaped
        };

        result = Mustache.render(template, view);
        expected = 'All special chars: &lt; &gt; &amp; &quot; &#39;';

        System.assertEquals(expected, result, 'All HTML special characters should be escaped');

        // Test with non-string values
        template = 'Number: {{number}}, Boolean: {{boolean}}, Null: {{nullValue}}';
        view = new Map<String, Object>{
            'number' => 42,
            'boolean' => true,
            'nullValue' => null
        };

        result = Mustache.render(template, view);
        expected = 'Number: 42, Boolean: true, Null: ';

        System.assertEquals(expected, result, 'Non-string values should be converted to strings and not escaped');
    }
}
