import { LoginExperience } from "./login-experience";

type LoginSearchParams = Record<string, string | string[] | undefined>;

function firstParam(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

export default async function LoginPage({
  searchParams,
}: {
  searchParams?: Promise<LoginSearchParams>;
}) {
  const params = searchParams ? await searchParams : {};
  return <LoginExperience nextPath={firstParam(params.next) ?? "/students"} />;
}
