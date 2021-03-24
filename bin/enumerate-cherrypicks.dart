import 'package:flutter_github_scripts/github_datatypes.dart';
import 'package:flutter_github_scripts/github_queries.dart';
import 'package:args/args.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class Options {
  final _parser = ArgParser(allowTrailingOptions: false);
  ArgResults _results;
  String get release => _results['release'];
  bool get html => _results['formatted'] ?? true;
  bool get summary => _results['summary'] ?? true;
  int get exitCode => _results == null
      ? -1
      : _results['help']
          ? 0
          : null;
  Options(List<String> args) {
    _parser
      ..addFlag('help',
          defaultsTo: false, abbr: 'h', negatable: false, help: 'get usage')
      ..addFlag('formatted', abbr: 'f', help: 'show html format')
      ..addFlag('summary', abbr: 's', help: 'show summary (TSV)')
      ..addOption('release',
          abbr: 'r', help: 'release to scan for cherrypick requests');

    try {
      _results = _parser.parse(args);
      if (_results['help']) _printUsage();
      if (_results['release'] == null)
        throw (ArgParserException('Need a version!'));
    } on ArgParserException catch (e) {
      print(e.message);
      _printUsage();
    }
  }

  void _printUsage() {
    print(
        'Usage: dart enumerate-cherrypicks.dart [--formatted] [--summary] --release release-version');
    print(_parser.usage);
  }
}

String hotfixSummary(Issue issue, String repository) {
  var result = '';
  var formatter = DateFormat('MM/dd/yy');
  var created = formatter.format(issue.createdAt);
  var fixed = formatter.format(issue.closedAt);
  // No easy way to determine code base from here if it's flutter
  var codebase = repository ?? '';
  result = '${result}\t${issue.url}';
  result = '${result}\t=HYPERLINK("${issue.url}",${issue.number})';
  result = '${result}\t${created}';
  result = '${result}\t${issue.title}';
  result = '${result}\t${codebase}';
  result = '${result}\t${fixed}';

  return result;
}

void main(List<String> args) async {
  final opts = Options(args);
  if (opts.exitCode != null) exit(opts.exitCode);
  final token = Platform.environment['GITHUB_TOKEN'];
  final github = GitHub(token);
  var release = opts.release;
  var flutterCherryPickLabel =
      'label:"cp: ${release}" -label:"cp: ${release} completed"';

  // Flutter issues are either open or closed, with the appropriate release cherrypick label.
  var flutterQuery = 'org:flutter is:issue ${flutterCherryPickLabel}';
  // Dart issues are closed, with the label `cherry-pick-review'
  var dartQuery = 'org:dart-lang is:issue is:open label:cherry-pick-review';

  // Now do the same for performance issues.
  var flutterIssues = await github.searchIssuePRs(flutterQuery);
  var dartIssues = await github.searchIssuePRs(dartQuery);

  if (opts.html) {
    print('<html>');

    print('<h3>Issues to pick into ${release}');

    print('<p>Flutter:</p>');
    await for (var issue in flutterIssues) {
      print('<li>${issue.html()}</li>');
    }

    print('<p>Dart:</p>');

    await for (var issue in dartIssues) {
      print(issue.html());
    }

    print('</html>');
  }
  print('');

  if (opts.summary) {
    // Flutter issues
    await for (var issue in flutterIssues) {
      print(hotfixSummary(issue, null));
    }

    await for (var issue in dartIssues) {
      print(hotfixSummary(issue, 'dartlang/sdk'));
    }
  }
}
