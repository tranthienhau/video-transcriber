import sys
import os
import anthropic


def generate(transcript_path: str, output_dir: str):
    with open(transcript_path) as f:
        transcript = f.read().strip()

    client = anthropic.Anthropic()

    # Generate English mind map + summary
    en_response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=4096,
        messages=[
            {
                "role": "user",
                "content": f"""From this transcript, generate TWO outputs separated by ===SEPARATOR===

OUTPUT 1 - A markdown mind map suitable for markmap rendering. Rules:
- Use # for the main title
- Use ## for major sections (numbered)
- Use - for bullet points, indented for sub-points
- Bold key terms with **
- Keep each bullet concise but informative
- Cover ALL main topics and key details from the transcript

OUTPUT 2 - A concise summary with:
- Speakers (if identifiable)
- Numbered sections with bullet points for each topic
- Key stats or numbers mentioned
- Announcements or action items

Transcript:
{transcript}""",
            }
        ],
    )

    en_text = en_response.content[0].text
    parts = en_text.split("===SEPARATOR===")

    mindmap_en = parts[0].strip()
    summary = parts[1].strip() if len(parts) > 1 else ""

    with open(os.path.join(output_dir, "mindmap_en.md"), "w") as f:
        f.write(mindmap_en)

    with open(os.path.join(output_dir, "summary.md"), "w") as f:
        f.write(summary)

    # Generate Vietnamese mind map
    vi_response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=4096,
        messages=[
            {
                "role": "user",
                "content": f"""Translate this mind map to Vietnamese. Keep technical terms in English (CLAUDE.md, MCP, hooks, sub-agents, CI/CD, Git, etc). Keep the same markdown structure.

{mindmap_en}""",
            }
        ],
    )

    mindmap_vi = vi_response.content[0].text
    with open(os.path.join(output_dir, "mindmap_vi.md"), "w") as f:
        f.write(mindmap_vi)

    print(f"  Generated: mindmap_en.md, mindmap_vi.md, summary.md")


if __name__ == "__main__":
    generate(sys.argv[1], sys.argv[2])
