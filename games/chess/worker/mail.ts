// Challenge emails, sent through Resend (resend.com) when RESEND_API_KEY and MAIL_FROM are set.
// Without them nothing is sent: the challenge still waits for the friend, who sees it when they
// sign in with that address, and the challenger gets a link to send them themselves.

export interface MailEnv { RESEND_API_KEY?: string; MAIL_FROM?: string }

export const canMail = (env: MailEnv) => Boolean(env.RESEND_API_KEY && env.MAIL_FROM);

const escape = (s: string) => s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

export function challengeMail(fromName: string, fromEmail: string, link: string): { subject: string; text: string; html: string } {
  const who = `${fromName} (${fromEmail})`;
  const subject = `${fromName} challenges you to a game of chess`;
  const text = `${who} has challenged you to a game of chess.\n\nAccept or decline here: ${link}\n\nSign in with Google or GitHub using this email address to play.`;
  const html = `<div style="font-family:monospace;background:#16142b;color:#f4e9cf;padding:24px">
<p style="font-size:18px;color:#ffcf5a">♞ A CHALLENGER APPEARS</p>
<p>${escape(who)} has challenged you to a game of chess.</p>
<p><a href="${escape(link)}" style="display:inline-block;background:#ffcf5a;color:#16142b;padding:10px 16px;text-decoration:none;font-weight:bold">ACCEPT OR DECLINE</a></p>
<p style="color:#a99fc9">Sign in with Google or GitHub using this email address to play.</p></div>`;
  return { subject, text, html };
}

/** Sends an email. Best effort: false when it couldn't be sent. */
export async function sendMail(env: MailEnv, to: string, msg: { subject: string; text: string; html: string }): Promise<boolean> {
  if (!canMail(env)) return false;
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: env.MAIL_FROM, to: [to], subject: msg.subject, text: msg.text, html: msg.html }),
    });
    return res.ok;
  } catch {
    return false;
  }
}
