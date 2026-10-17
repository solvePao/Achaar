import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = fileURLToPath(new URL('../', import.meta.url));
const sources = ['App/AppSettings.swift', 'Core/Web/InstagramRouting.swift',
    'Core/Privacy/UsageTracker.swift', 'Core/Privacy/TrackerProtection.swift',
    'Core/Privacy/WebsiteDataCleaner.swift'];
function check(transform = files => files) {
    const directory = mkdtempSync(path.join(tmpdir(), 'achaar-coverage-'));
    try {
        const files = sources.map(source => ({
            path: path.join(root, 'Achaar', source), coveredLines: 91, executableLines: 100
        }));
        const report = { targets: [{ name: 'AchaarCoreTests.xctest', files: transform(files) }] };
        const reportPath = path.join(directory, 'coverage.json');
        writeFileSync(reportPath, JSON.stringify(report));
        return spawnSync(process.execPath, [path.join(root, 'Scripts/check-coverage.mjs'), reportPath], { encoding: 'utf8' });
    } finally {
        rmSync(directory, { recursive: true, force: true });
    }
}
test('excludes test source even when checkout directory is named Achaar', () => {
    const result = check(files => [...files, {
        path: path.join(root, 'AchaarTests/AchaarTests.swift'), coveredLines: 0, executableLines: 10000
    }]);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /91\.00% \(455\/500 executable lines\)/);
});
test('rejects exactly 90% in one file despite a passing aggregate', () => {
    const result = check(files => { files[0].coveredLines = 90; return files; });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /strictly above 90%/);
});
test('rejects a required source omitted from the report', () => {
    const result = check(files => files.slice(1));
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /Missing production coverage/);
});
test('automatically gates newly reported production sources', () => {
    const result = check(files => [...files, {
        path: path.join(root, 'Achaar/Core/NewLogic.swift'), coveredLines: 10, executableLines: 100
    }]);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /NewLogic.swift must have line coverage/);
});
