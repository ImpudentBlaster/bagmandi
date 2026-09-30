const LOGO_SRC = '/bagmandi_logo.png'

export function BrandLogo({
  size = 40,
  className = '',
}: {
  size?: number
  className?: string
}) {
  return (
    <img
      src={LOGO_SRC}
      alt="BagMandi"
      width={size}
      height={size}
      className={`rounded-[18%] object-cover shrink-0 ${className}`}
      style={{ width: size, height: size }}
    />
  )
}
