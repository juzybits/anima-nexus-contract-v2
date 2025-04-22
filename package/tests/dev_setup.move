#[test_only]
module nexus_launchpad::dev_setup;

use sui::{
    clock::Clock,
    package::{Publisher},
};
use nexus_launchpad::{
    dev_nft::{Self, DevNft},
    launch::{Self},
    phase::{Self},
    whitelist::{Self},
};

#[allow(lint(self_transfer))]
public fun dev_setup<C>(
    publisher: &Publisher,
    item_price: u64,
    launch_total_supply: u64,
    phase_max_mint_allocation: u64,
    phase_max_mint_count: u64,
    phase_allow_bulk_mint: bool,
    wl_amount: u64,
    kiosk_req: launch::KioskRequirement,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // create launch
    let (
        mut launch,
        launch_admin_cap,
        share_promise,
    ) = launch::new<DevNft>(
        publisher,
        launch_total_supply,
        kiosk_req,
        ctx,
    );

    launch.add_operator(&launch_admin_cap, ctx.sender());
    let launch_operator_cap = launch.request_operator_cap(ctx);

    // add items to launch
    let items = vector::tabulate!(
        launch_total_supply,
        |i| dev_nft::new_dev_nft(
            b"Demo NFT",
            i + 1,
            b"https://images.stockcake.com/public/a/8/e/a8e29d30-9da7-418b-932b-c12c3260c2ef_medium/abstract-geometric-design-stockcake.jpg",
            ctx,
        )
    );
    launch.add_items(&launch_operator_cap, items);

    // activate launch
    launch.set_active_state(&launch_operator_cap);

    // create phase
    let phase_kind = if (wl_amount > 0) {
        phase::new_phase_kind_whitelist()
    } else {
        phase::new_phase_kind_public()
    };
    let (mut phase, schedule_promise) = phase::new<DevNft>(
        &launch_operator_cap,
        &launch,
        phase_kind,
        option::some(b"Phase Name".to_string()),
        option::some(b"Phase Description".to_string()),
        clock.timestamp_ms() + 1,
        clock.timestamp_ms() + 7 * 24 * 60 * 60 * 1000, // 1 week
        phase_max_mint_allocation,
        phase_max_mint_count,
        phase_allow_bulk_mint,
        clock,
        ctx,
    );

    // add payment option
    phase.add_payment_type<DevNft, C>(&launch_operator_cap, item_price);

    // send whitelist objects to sender
    wl_amount.do!(|_| {
        let wl = whitelist::new<DevNft>(&launch_operator_cap, &mut launch, &mut phase, ctx);
        transfer::public_transfer(wl, ctx.sender());
    });

    // schedule phase
    phase.register(
        schedule_promise,
        &launch_operator_cap,
        &mut launch,
    );

    // === clean up ===

    launch.share(share_promise);
    transfer::public_transfer(launch_admin_cap, ctx.sender());
}
