import { PortfolioEntry } from './portfolio';

const columns = ['Name', 'Type', 'Category', 'Currency', 'Value', 'Created at', 'Updated at'];

function cell(value: unknown): string {
  const text = value === undefined || value === null ? '' : String(value);
  return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

function textCell(value: unknown): string {
  const text = value === undefined || value === null ? '' : String(value);
  return cell(/^[=+\-@]/.test(text) ? `'${text}` : text);
}

export function portfolioCsv(entries: PortfolioEntry[]): string {
  const rows = entries.map((entry) => [
    textCell(entry.name),
    textCell(entry.kind),
    textCell(entry.category),
    textCell(entry.currency),
    cell(entry.value),
    cell(entry.createdAt),
    cell(entry.updatedAt),
  ].join(','));

  return `\uFEFF${[columns.map(cell).join(','), ...rows].join('\r\n')}\r\n`;
}

export const portfolioCsvFilename = 'wealthmax-portfolio.csv';
