// Evaluate xccov JSON without counting executable lines in the XCTest source.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const reportPath = process.argv[2];
if (!reportPath) throw new Error('Usage: node Scripts/check-coverage.mjs <xccov-report.json>');
const report = JSON.parse(readFileSync(reportPath, 'utf8'));
const target = report.targets?.find(target => target.name === 'AchaarCoreTests.xctest');
if (!target) throw new Error('AchaarCoreTests coverage is missing');
const required = [
    'App/AppSettings.swift', 'Core/Web/InstagramRouting.swift',
    'Core/Privacy/UsageTracker.swift', 'Core/Privacy/TrackerProtection.swift',
    'Core/Privacy/WebsiteDataCleaner.swift'
];
// Include every production source reported by this target, including future additions.
const sourceRoot = fileURLToPath(new URL('../Achaar/', import.meta.url));
const files = (target.files ?? []).filter(file => {
    const relative = path.relative(sourceRoot, file.path);
    return !relative.startsWith('..') && !path.isAbsolute(relative) && relative.endsWith('.swift');
});
for (const source of required) {
    if (!files.some(file => file.path.endsWith(`/Achaar/${source}`))) {
        throw new Error(`Missing production coverage: ${source}`);
    }
}
let covered = 0, executable = 0;
for (const file of files) {
    if (!Number.isInteger(file.coveredLines) || !Number.isInteger(file.executableLines)
        || file.executableLines <= 0 || file.coveredLines < 0 || file.coveredLines > file.executableLines) {
        throw new Error(`Invalid coverage counts: ${file.path}`);
    }
    covered += file.coveredLines;
    executable += file.executableLines;
    const percentage = file.coveredLines / file.executableLines * 100;
    console.log(`${path.basename(file.path)}: ${percentage.toFixed(2)}% (${file.coveredLines}/${file.executableLines})`);
    if (percentage <= 90) throw new Error(`${file.path} must have line coverage strictly above 90%`);
}
const percentage = covered / executable * 100;
console.log(`Shared production code: ${percentage.toFixed(2)}% (${covered}/${executable} executable lines)`);
if (!(percentage > 90)) throw new Error('Shared production coverage must be strictly above 90%');
