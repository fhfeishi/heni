import { fireEvent, render } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { SceneryBackdrop } from "./SceneryBackdrop";

describe("SceneryBackdrop", () => {
  it("keeps zero intensity independent of full reveal after image load", () => {
    const { container } = render(<SceneryBackdrop activeView="now-playing" imageUrl="/fixture.png" intensity={0} reveal={100} />);
    const image = container.querySelector("img");
    if (image === null) throw new Error("Expected background image");
    fireEvent.load(image);
    expect(container.firstChild).toHaveAttribute("data-image-state", "ready");
    expect(container.firstChild).toHaveStyle({ "--scenery-intensity": "0", "--scenery-image-opacity": "1", "--scenery-image-shade": "0%" });
  });
  it("uses a quieter playback treatment and a denser browse treatment", () => {
    const { container, rerender } = render(
      <SceneryBackdrop activeView="now-playing" />,
    );
    expect(container.firstChild).toHaveClass("app-scenery--playback");
    expect(container.firstChild).toHaveAttribute("data-image-state", "fallback");

    rerender(<SceneryBackdrop activeView="library" />);
    expect(container.firstChild).toHaveClass("app-scenery--browse");
  });

  it("keeps the palette fallback when an optional image cannot load", () => {
    const { container } = render(
      <SceneryBackdrop
        activeView="queue"
        imageUrl="/missing-scenery-image.jpg"
      />,
    );
    const image = container.querySelector(".app-scenery__image");
    if (image === null) {
      throw new Error("Expected the optional scenery image to render.");
    }

    fireEvent.error(image);

    expect(container.firstChild).toHaveAttribute("data-image-state", "failed");
    expect(container.querySelector(".app-scenery__image")).toBeNull();
  });
});
